module game.level;

import game.components;
import game.systems;
import game.world;

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

	static assert(typeof(index).min < 0, "index must not be able to underflow at 0");

	void update()
	{
		if (world.speed > 0)
		{
			while (index < events.length && events[index].time <= world.now)
			{
				events[index].call(events[index]);
				index++;
			}
		}
		else
		{
			while (index > 0 && events[index - 1].time > world.now)
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
				index++;
		}
	}
}
