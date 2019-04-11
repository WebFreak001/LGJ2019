module game.world;

import d2d;

import std.algorithm;
import std.array;
import std.conv;
import std.range;

struct History
{
	double start, end;
	void delegate() _onUnstart;
	void delegate() _onRestart;
	void delegate() _onFinish;
	void delegate() _onUnfinish;
	void delegate(double progress, double deltaTime) _update;
	bool finished;

	// forward life-cycle:
	// onRestart()
	// update()...
	// onFinish()

	// backward life-cycle:
	// onUnfinish()
	// update()...
	// onUnstart()

	void onUnstart()
	{
		if (_onUnstart)
			_onUnstart();
	}

	void onRestart()
	{
		if (_onRestart)
			_onRestart();
	}

	void onFinish()
	{
		if (_onFinish)
			_onFinish();
	}

	void onUnfinish()
	{
		if (_onUnfinish)
			_onUnfinish();
	}

	void update(double progress, double deltaTime)
	{
		if (_update)
			_update(progress, deltaTime);
	}
}

class Entity
{
	bool dead;

	vec2 position;
}

class Player
{
	vec2 position;
	int speed;
	vec2 velocity;

	void updatePosition()
	{
		position += velocity.normalized() * speed; 
	}
}

struct World
{
	@disable this(this);

	double now() @property const
	{
		return time;
	}

	private double time = 0;
	double speed = 1;
	/// sorted by start time
	History[] events;
	ptrdiff_t eventStartIndex;
	ptrdiff_t eventEndIndex;

	Entity[] entities;
	Player player;

	void put(History event)
	{
		// TODO: insert events into history
		if (eventEndIndex < events.length)
			events.length = eventEndIndex;

		if (events.length)
			assert(events[$ - 1].start < event.start);

		events.assumeSafeAppend ~= event;
	}

	void update(double t)
	{
		double start = time;
		double dt = t * speed;
		time += dt;

		if (time > start)
		{
			// finish just-finished events
			foreach (ref started; events[eventStartIndex .. eventEndIndex])
			{
				if (started.finished || started.end > time)
					continue;

				started.finished = true;
				started.update(1, started.end - start);
				started.onFinish();
			}

			// move start index when events finish (to iterate less and to have a minimum active item)
			while (eventStartIndex < eventEndIndex && events[eventStartIndex].finished)
				eventStartIndex++;

			// update active events
			foreach (ref event; events[eventStartIndex .. eventEndIndex])
			{
				if (!event.finished)
					event.update((time - event.start) / (event.end - event.start), dt);
			}

			// start just-started events
			foreach (ref planned; events[eventEndIndex .. $])
			{
				if (planned.start > time)
					break;

				planned.onRestart();
				if (planned.end < time)
				{
					planned.finished = true;
					planned.update(1, planned.end - planned.start);
					planned.onFinish();
				}
				else
				{
					planned.finished = false;
					planned.update((time - planned.start) / (planned.end - planned.start),
							time - planned.start);
				}
				eventEndIndex++;
			}
		}
		else if (time < start)
		{
			// reduce eventEndIndex if events have unhappened
			foreach_reverse (ref unhappened; events[eventStartIndex .. eventEndIndex])
			{
				// iterate events from latest to earliest
				// events: 8  10      15
				// time:       time=14  start=16
				// d = -2
				// event at 15 must unhappen in this case
				// delta for event is -1 (15 - 16)
				// all events before time continue normally
				if (unhappened.start < time)
					break;

				eventEndIndex--;
				if (unhappened.finished)
					unhappened.onUnfinish();
				else
					unhappened.finished = true;
				unhappened.update(0, unhappened.start - start);
				unhappened.onUnstart();
			}

			// restart previous events (including any in current event list)
			// I think we need to iterate the entire event here because the very first event could be a 10 minute event that expired and all events following that would already be expired too,
			// so breaking on the first expired one from reverse wouldn't work.
			foreach_reverse (i, ref unhappened; events[0 .. eventEndIndex])
			{
				if (!unhappened.finished || unhappened.end <= time)
					continue;

				unhappened.finished = false;
				unhappened.onUnfinish();
				unhappened.update((time - unhappened.start) / (unhappened.end - unhappened.start),
						start - unhappened.end);
				if (i < eventStartIndex)
					eventStartIndex = i;
			}

			// update active events
			foreach (ref event; events[eventStartIndex .. eventEndIndex])
			{
				if (!event.finished)
					event.update((time - event.start) / (event.end - event.start), dt);
			}
		}
		// else nan or equal
	}
}
