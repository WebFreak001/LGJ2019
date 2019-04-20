module game.level;

import game.components;
import game.entities.bullet;
import game.systems;
import game.world;

import std.algorithm;
import std.conv;
import std.json;
import std.math;
import std.stdio;
import std.string;

/// A Section is a list of reversible events that can occur multiple times.
struct Section
{
	struct Event
	{
		double time;
		void delegate(ref Event self) call;
		bool finished;
	}

	Event[] events;
	int index;
	double startTime;

	static assert(typeof(index).min < 0, "index must not be able to underflow at 0");

	double now() @property const
	{
		return world.now - startTime;
	}

	void update()
	{
		if (isNaN(startTime))
			startTime = world.now;

		if (world.speed > 0)
		{
			while (index < events.length && events[index].time <= now)
			{
				events[index].call(events[index]);
				index++;
			}
		}
		else
		{
			while (index > 0 && events[index - 1].time > now)
			{
				events[index - 1].finished = false;
				index--;
			}
		}
	}
}

/// A level is a list of sections
/// See_Also: Section
struct Level
{
	Section[] sections;
	int index;

	void update()
	{
		if (world.cleaning)
			return;

		if (index < sections.length)
		{
			sections[index].update();

			bool allDone = true;
			foreach_reverse (ref event; sections[index].events)
			{
				if (!event.finished)
				{
					allDone = false;
					break;
				}
			}
			if (allDone)
			{
				index++;
				world.cleanHistory();
			}
		}
	}

	static Level parse(Lines)(Lines lines)
	{
		Level ret;
		GenericEntityBuilder[string] generators;

		size_t lineNo;
		foreach (line; lines)
		{
			lineNo++;
			line = line.strip;
			if (!line.length || line.startsWith("#"))
				continue;

			auto test = line.startsWith("generator", "bullets", "unset", "push",
					"patch", "spawn", "wait");
			if (test == 0)
			{
				stderr.writeln("Syntax error in line ", lineNo,
						": Unexpected statement, expected generator, bullets, unset or push");
			}
			else if (test == 1)
			{
				// generator
				line = line["generator".length .. $].stripLeft;
				auto parts = line.findSplit(" ");
				auto name = parts[0];
				auto file = parts[2].stripLeft;
				if (!file.startsWith("from"))
				{
					stderr.writeln("Syntax error in line ", lineNo,
							": Expected generator name to follow 'from'");
					continue;
				}

				file = file[4 .. $].stripLeft;
				generators[name.idup] = GenericEntityBuilder.fromFile(file);
			}
			else if (test == 2)
			{
				// bullets
				line = line["bullets".length .. $].stripLeft;
				auto parts = line.findSplit(" ");
				auto dstName = cast(string) parts[0];
				auto genName = cast(string) parts[2];

				if (auto dst = dstName in generators)
				{
					if (auto gen = genName in generators)
					{
						dst.bullets ~= *gen;
					}
					else
					{
						stderr.writeln("Error in line ", lineNo, ": Could not find generator '", genName, "'");
					}
				}
				else
				{
					stderr.writeln("Error in line ", lineNo, ": Could not find generator '", dstName, "'");
				}
			}
			else if (test == 3)
			{
				// unset
				line = line["unset".length .. $].stripLeft;
				if (line.startsWith("generator"))
				{
					line = line["generator".length .. $].stripLeft;
					auto name = cast(string) line;
					if (name !in generators)
						stderr.writeln("Error in line ", lineNo,
								": Trying to undefine non-existant generator");
				}
				else
					stderr.writeln("Syntax error in line ", lineNo, ": Unknown directive to unset");
			}
			else if (test == 4)
			{
				// push
				line = line["push".length .. $].stripLeft;
				if (line.startsWith("section"))
					ret.sections ~= Section.init;
				else
					stderr.writeln("Syntax error in line ", lineNo, ": Unknown directive to push");
			}
			else if (test == 5)
			{
				// patch
				line = line["patch".length .. $].stripLeft;
				auto parts = line.findSplit(" ");
				auto name = cast(string) parts[0];

				if (auto gen = name in generators)
				{
					auto json = parseJSON(parts[2].stripLeft);
					foreach (key, value; json.object)
						gen.setJson(key, value);
				}
				else
					stderr.writeln("Error in line ", lineNo, ": Could not find generator '", name, "'");
			}
			else if (test == 6)
			{
				// spawn
				line = line["spawn".length .. $].stripLeft;
				auto start = parseDuration(line, lineNo);
				auto parts = line.findSplit(" ");
				auto name = cast(string) parts[0];

				if (auto gen = name in generators)
				{
					line = parts[2].stripLeft;
					if (line.length)
					{
						auto json = parseJSON(line);
						foreach (key, value; json.object)
							gen.setJson(key, value);
					}
					ret.sections[$ - 1].events ~= Section.Event(start, gen.store());
				}
				else
					stderr.writeln("Error in line ", lineNo, ": Could not find generator '", name, "'");
			}
			else if (test == 7)
			{
				// wait
				line = line["wait".length .. $].stripLeft;
				auto start = parseDuration(line, lineNo);
				auto length = parseDuration(line, lineNo);

				if (!isNaN(start) && !isNaN(length))
				{
					ret.sections[$ - 1].events ~= Section.Event(start, (ref event) {
						if (length == double.infinity)
						{
							writeln("endless wait (level won't terminate)");
						}
						else
						{
							world.put(History.makeTrigger(start + length, {
									event.finished = false;
								}, { event.finished = true; }));
						}
					});
				}
			}
		}

		return ret;
	}
}

double parseDuration(ref char[] line, size_t lineNo)
{
	auto parts = line.findSplit(" ");
	line = parts[2].stripLeft;

	if (parts[0] == "nan")
		return double.nan;

	if (parts[0] == "inf")
		return double.infinity;

	if (!parts[0].endsWith("ms", "s"))
	{
		stderr.writeln("Syntax error in line ", lineNo, ": duration must end with s or ms");
		return double.nan;
	}

	if (parts[0].endsWith("ms"))
		return parts[0][0 .. $ - 2].to!double / 1000;
	else
		return parts[0][0 .. $ - 1].to!double;
}
