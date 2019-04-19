module game.world;

import d2d;

import std.algorithm;
import std.array;
import std.conv;
import std.range;
import std.meta;

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

	static History make(double start, double end, IHistory callbacks)
	{
		//dfmt off
		History ret = {
			start: start,
			end: end,
			_onUnstart: &callbacks.onUnstart,
			_onRestart: &callbacks.onRestart,
			_onFinish: &callbacks.onFinish,
			_onUnfinish: &callbacks.onUnfinish,
			_update: &callbacks.update
		};
		//dfmt on
		return ret;
	}
}

interface IHistory
{
	void onUnstart();
	void onRestart();
	void onFinish();
	void onUnfinish();
	void update(double progress, double deltaTime);
}

alias Dead = Flag!"dead";

struct Entity
{
	__gshared static uint counter;

	private this(uint id)
	{
		this.id = id;
	}

	private enum deadMask = 0x8000_0000U;

	uint id;
	uint components;

	static Entity create()
	{
		return Entity(counter++);
	}

	bool dead() @property const
	{
		return !!(components & deadMask);
	}

	bool dead(bool set) @property
	{
		if (set)
			components |= deadMask;
		else
			components &= ~deadMask;
		return set;
	}

	bool hasComponentIndex(int index) @property const
	{
		return !!(components & (1U << index));
	}
}

ptrdiff_t binarySearch(alias cmp, T)(auto ref const T[] array)
{
	ptrdiff_t l;
	ptrdiff_t r = array.length;
	while (l <= r)
	{
		auto m = (l + r) / 2;
		auto c = cmp(array.ptr[m]);
		if (c < 0)
			l = m + 1;
		else if (c > 0)
			r = m - 1;
		else
			return m;
	}
	return ~l;
}

struct World(Components...)
{
	static assert(Components.length <= 32, "Can manage at most 32 components");

	@disable this(this);

	double now() @property const
	{
		return time;
	}

	/// World entity with one of each component
	static struct WorldEntity
	{
		Entity entity;
		Components components;

		void removeComponent(Component)()
		{
			enum index = staticIndexOf!(Component, Components);
			static assert(index != -1, "Component " ~ Component.stringof ~ " is not registered!");
			components[index] = Component.init;
			entity.components &= ~(1U << index);
		}

		void write(Component)(Component v)
		{
			enum index = staticIndexOf!(Component, Components);
			static assert(index != -1, "Component " ~ Component.stringof ~ " is not registered!");
			components[index] = v;
			entity.components |= 1U << index;
		}

		Component read(Component)()
		{
			enum index = staticIndexOf!(Component, Components);
			static assert(index != -1, "Component " ~ Component.stringof ~ " is not registered!");
			return components[index];
		}

		Component* get(Component)()
		{
			enum index = staticIndexOf!(Component, Components);
			static assert(index != -1, "Component " ~ Component.stringof ~ " is not registered!");

			return entity.hasComponentIndex(index) ? &components[index] : null;
		}

		ref Component force(Component)()
		{
			enum index = staticIndexOf!(Component, Components);
			static assert(index != -1, "Component " ~ Component.stringof ~ " is not registered!");
			assert(entity.hasComponentIndex(index));
			return components[index];
		}
	}

	private double time = 0;
	double normalSpeed = 1;
	double speed = 1;
	/// sorted by start time
	History[] events;
	ptrdiff_t eventStartIndex;
	ptrdiff_t eventEndIndex;

	WorldEntity[] entities;

	/// Returns the index of the entity in the entities array or the bitwise complement of the element that is immediately smaller than the seach item. (~n, always negative)
	ptrdiff_t getEntity(Entity entity)
	{
		return entities.binarySearch!((a) => cast(long) a.entity.id - cast(long) entity.id);
	}

	Entity putEntity(Coms...)(Coms components)
	{
		WorldEntity entity;
		entity.entity = Entity.create();

		foreach (com; components)
		{
			static if (is(typeof(com) == Dead))
			{
				entity.entity.dead = !!com;
			}
			else
			{
				enum Index = staticIndexOf!(typeof(com), Components);
				static assert(Index != -1, "Component " ~ typeof(com).stringof ~ " is not registered!");
				entity.write(com);
			}
		}

		assert(!entities.length || entities[$ - 1].entity.id < entity.entity.id,
				"entity ids must be linearly growing!");
		entities.assumeSafeAppend ~= entity;
		return entity.entity;
	}

	void put(History event)
	{
		if (eventEndIndex < events.length)
			events.length = eventEndIndex;

		if (!events.length || event.start >= events[$ - 1].start)
		{
			events.assumeSafeAppend ~= event;
			return;
		}
		else
			events.assumeSafeAppend ~= event;

		auto index = events[0 .. $ - 1].binarySearch!((a) => a.start - event.start);
		if (index < 0)
			index = ~index;
		if (index < eventEndIndex)
			eventEndIndex++;

		if (index < eventStartIndex)
		{
			event.onRestart();
			if (now > event.end)
			{
				event.update(0, 0);
				event.onFinish();
				event.finished = true;
			}
			else
			{
				assert(now >= event.start);
				event.update((now - event.start) / (event.end - event.start), 0);
				event.finished = false;
			}
			eventStartIndex++;
		}
		else
		{
			if (now >= event.start)
			{
				event.onRestart();
				event.update((now - event.start) / (event.end - event.start), 0);
			}
			event.finished = false;
		}

		foreach_reverse (i; index .. events.length)
			events[i] = events[i - 1];
		events[index] = event;

		assert(events.isSorted!"a.start <= b.start");
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
				if (planned.start > time || planned.finished)
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
