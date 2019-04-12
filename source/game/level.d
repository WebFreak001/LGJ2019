module game.level;

import game.components;
import game.systems;
import game.world;

/// A Section is a list of reversible events that can occur multiple times.
struct Section
{
	struct Event
	{
		bool finished;
		double time;
		void delegate(ref GameWorld world, ref Event self) call;
	}

	Event[] events;
	int index;

	static assert(typeof(index).min < 0, "index must not be able to underflow at 0");

	void update(ref GameWorld world)
	{
		if (world.speed > 0)
		{
			while (index < events.length && events[index].time >= world.now)
			{
				events[index].call(world, events[index]);
				index++;
			}
		}
		else
		{
			while (index >= 0 && events[index].time < world.now)
			{
				events[index].finished = false;
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

	void update(ref GameWorld world)
	{
		if (index < sections.length)
		{
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
