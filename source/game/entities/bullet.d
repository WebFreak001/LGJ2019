module game.entities.bullet;

import d2d;

import std.algorithm;
import std.conv;
import std.json;
import std.math;
import std.stdio;
import std.traits;

import std.stdio : stderr;

import crunch;

import game.components;
import game.level;
import game.systems;
import game.world;

import resources;

abstract class HistoryEntity : IHistory
{
	protected Entity entity;
	protected vec2 start;
	protected double delay, lifeTime;

	void delegate() onDeath = null;

	uint historyID;

	void create(vec2 start, double delay, double lifeTime)
	{
		this.start = start;
		this.delay = delay;
		this.lifeTime = lifeTime;

		makeEntity(start, delay, lifeTime);
		initializeEntity();
		auto event = History.make(world.now + delay, world.now + delay + lifeTime, this);
		historyID = event.id;
		world.put(event);
	}

	protected void makeEntity(vec2 start, double delay, double lifeTime)
	{
		entity = world.putEntity(Dead.yes, PositionComponent(start));
	}

	protected void initializeEntity()
	{
	}

	final void makeDead(bool dead)
	{
		this.edit!((ref entity) { entity.entity.dead = dead; });

		if (dead && onDeath)
			onDeath();
	}

	void onUnstart()
	{
		makeDead(true);
	}

	void onRestart()
	{
		makeDead(false);
	}

	void onFinish()
	{
		makeDead(true);
	}

	void onUnfinish()
	{
		makeDead(false);
	}

	abstract void update(double progress, double deltaTime);
}

abstract class DrawableHistoryEntity : HistoryEntity
{
	Crunch.Image sprite;
	float rotation;
	vec2 scale;
	vec4 color;

	this(Crunch.Image sprite, float rotation = 0, vec2 scale = vec2(1), vec4 color = vec4(1))
	{
		this.sprite = sprite;
		this.rotation = rotation;
		this.scale = scale;
		this.color = color;
	}

	protected override void makeEntity(vec2 start, double delay, double lifeTime)
	{
		entity = world.putEntity(Dead.yes, PositionComponent(start),
				ComplexDisplayComponent(sprite, scale, rotation, DrawOrigin.middleCenter, vec2(0), color));
	}
}

void edit(alias cb)(HistoryEntity he)
{
	editEntity!cb(he.entity);
}

class DirectionalDrawableHistoryEntity(alias interp) : DrawableHistoryEntity
{
	vec2 velocity;
	vec2 end;

	this(Crunch.Image sprite, vec2 velocity, vec2 scale = vec2(1),
			vec4 color = vec4(1), float rotation = float.nan)
	{
		if (isNaN(rotation))
			rotation = atan2(velocity.y, velocity.x);
		super(sprite, rotation, scale, color);
		this.velocity = velocity;
	}

	override void create(vec2 start, double delay, double lifeTime)
	{
		super.create(start, delay, lifeTime);

		end = start + velocity * lifeTime;
	}

	override void update(double progress, double deltaTime)
	{
		this.edit!((ref entity) {
			entity.write(PositionComponent(interp(this, start, end, progress)));
		});
	}
}

alias LinearDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((e,
		start, end, t) => (end - start) * t + start);

alias QuadraticDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((e,
		start, end, t) => (end - start) * t * t + start);

alias CubicDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((e, start,
		end, t) => (end - start) * t * t * t + start);

alias QuarticDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((e,
		start, end, t) => (end - start) * t * t * t * t + start);

alias QuinticDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((e,
		start, end, t) => (end - start) * t * t * t * t * t + start);

alias InterpolationFunc = vec2 delegate(vec2 start, vec2 end, double progress);

class GenericDrawableHistoryEntity : DirectionalDrawableHistoryEntity!((e, start,
		end, t) => (cast(GenericDrawableHistoryEntity) e).interpolate(start, end, t))
{
	this(Crunch.Image sprite, vec2 velocity, vec2 scale = vec2(1),
			vec4 color = vec4(1), float rotation = float.nan)
	{
		super(sprite, velocity, scale, color, rotation);
	}

	InterpolationFunc interpolate;
}

enum InterpolationFuncs : InterpolationFunc
{
	linear = (start, end, t) => (end - start) * t + start,
	quadratic = (start, end,
			t) => (end - start) * t * t + start,
	cubic = (start, end,
			t) => (end - start) * t * t * t + start,
	quartic = (start, end,
			t) => (end - start) * t * t * t * t + start,
	quintic = (start, end,
			t) => (end - start) * t * t * t * t * t + start,
}

class BasicMovingEntity(Base) : Base
{
	CollisionComponent collision;
	HealthComponent health;
	int collisionIndex;

	this(Crunch.Image sprite, vec2 velocity, vec2 scale = vec2(1),
			vec4 color = vec4(1), float rotation = float.nan)
	{
		super(sprite, velocity, scale, color, rotation);
	}

	typeof(this) maxHealth(int maxHp)
	{
		health.maxHp = health.hp = maxHp;
		return this;
	}

	typeof(this) invulnTime(double invulnTime)
	{
		health.invulnerabilityTime = invulnTime;
		return this;
	}

	typeof(this) type(CollisionComponent.Mask type)
	{
		collision.type = type;
		return this;
	}

	typeof(this) addCircle(CollisionComponent.Mask mask, vec2 position, float radius)
	{
		collision.circles[collisionIndex].mask = mask;
		collision.circles[collisionIndex].center = position;
		collision.circles[collisionIndex].radius = radius;
		collisionIndex++;

		return this;
	}

	protected override void initializeEntity()
	{
		this.edit!((ref entity) {
			entity.write(collision);
			if (health.maxHp > 0)
			{
				health.onDamage = &onDamage;
				entity.write(health);
			}
		});
	}

	protected void onDamage(ref GameWorld.WorldEntity entity, int dmg)
	{
		assert(entity.entity.id == this.entity.id);

		if (dmg == 0)
			return;

		// TODO: record undo trigger which undoes damage/death
		world.put(History.makeTrigger(world.now, {
				edit!((ref entity) {
					auto health = entity.get!HealthComponent;
					if (health)
					{
						health.gotHit(entity, -dmg, false);
						if (health.hp > 0)
							makeDead(false);
					}
				})(this);
			}, {
				edit!((ref entity) {
					auto health = entity.get!HealthComponent;
					if (health)
					{
						health.gotHit(entity, dmg, false);
						if (health.hp <= 0)
							makeDead(true);
					}
				})(this);
			}));
	}
}

alias LinearEntity = BasicMovingEntity!LinearDrawableHistoryEntity;
alias QuadraticEntity = BasicMovingEntity!QuadraticDrawableHistoryEntity;
alias GenericMovingEntity = BasicMovingEntity!GenericDrawableHistoryEntity;

class GenericEntityBuilder
{
	Crunch.Image sprite;
	vec2 position;
	double offset = 0, length = 0;
	vec2 velocity = vec2(0);
	InterpolationFunc interpolation = InterpolationFuncs.linear;
	vec2 scale = vec2(1);
	vec4 color = vec4(1);
	float rotation = float.nan;
	int maxHp;
	double invulnTime;
	CollisionComponent.Mask collision;

	CollisionComponent.Circle[] circles;

	double bulletInterval = 1;
	GenericEntityBuilder bullets;

	bool setJson(string property, JSONValue json)
	{
		switch (property)
		{
		case "sprite":
			if (json.type != JSONType.string)
			{
				stderr.writeln("sprite property only accepts string values");
				return false;
			}
			string target = json.str;
			foreach (ref image; R.spritesheet.sprites.textures[0].images)
			{
				if (image.name == target)
				{
					sprite = image;
					return true;
				}
			}
			stderr.writeln("Could not find sprite ", target);
			return false;
		case "position":
			return readVector(property, json, position);
		case "velocity":
			return readVector(property, json, velocity);
		case "scale":
			return readVector(property, json, scale);
		case "color":
			return readVector(property, json, color);
		case "offset":
			return readNumeric(property, json, offset);
		case "length":
			return readNumeric(property, json, length);
		case "rotation":
			return readNumeric(property, json, rotation);
		case "max_hp":
		case "hp":
			return readNumeric(property, json, maxHp);
		case "invulnerability_time":
		case "invuln_time":
		case "itime":
			return readNumeric(property, json, invulnTime);
		case "mask":
		case "type":
			return readCollisionMask(property, json, collision);
		case "bullet_interval":
			return readNumeric(property, json, bulletInterval);
		case "circles":
			if (json.type == JSONType.null_)
			{
				circles.length = 0;
				return true;
			}
			if (json.type != JSONType.array)
			{
				stderr.writeln("circles property only accepts arrays of objects or null");
				return false;
			}
			circles.length = 0;
			foreach (circle; json.array)
				setJson("circle", circle);
			return true;
		case "circle":
			if (json.type != JSONType.object)
			{
				stderr.writeln("circle property only accepts object values");
				return false;
			}
			CollisionComponent.Circle circle;
			foreach (key, value; json.object)
			{
				switch (key)
				{
				case "center":
				case "offset":
					readVector(key, value, circle.center);
					break;
				case "radius":
					readNumeric(key, value, circle.radius);
					break;
				case "mask":
					CollisionComponent.Mask mask;
					if (readCollisionMask(key, value, mask))
						circle.mask = cast(uint) mask;
					break;
				default:
					stderr.writeln("ignoring unknown circle property: ", key);
					break;
				}
			}
			circles ~= circle;
			return true;
		default:
			stderr.writeln("Ignoring unknown entity builder property: ", property);
			return false;
		}
	}

	GenericMovingEntity prepare()
	{
		auto entity = new GenericMovingEntity(sprite, velocity, scale, color, rotation);
		if (maxHp != 0)
			entity.maxHealth(maxHp);
		if (collision != typeof(collision).init)
			entity.type(collision);
		if (interpolation !is null)
			entity.interpolate = interpolation;

		foreach (circle; circles)
			entity.addCircle(cast(CollisionComponent.Mask) circle.mask, circle.center, circle.radius);
		return entity;
	}

	void delegate(ref Section.Event event) store()
	{
		auto position = this.position;
		auto offset = this.offset;
		auto length = this.length;
		auto entity = prepare();
		return (ref event) {
			entity.create(position, offset, length);
			postSpawn(event, entity);
		};
	}

	GenericMovingEntity build()
	{
		GenericMovingEntity entity = prepare();
		entity.create(position, offset, length);
		return entity;
	}

	GenericMovingEntity build(ref Section.Event event)
	{
		auto entity = build();
		postSpawn(event, entity);
		return entity;
	}

	void postSpawn(ref Section.Event event, GenericMovingEntity entity)
	{
		auto start = world.now + offset;

		entity.onDeath = () {
			event.finished = true;
			world.endNow(start, entity.historyID);
		};

		if (bulletInterval > 0 && bullets !is null)
			makeChildEffects(event, entity, world.now + bulletInterval);
	}

	void makeChildEffects(ref Section.Event event, GenericMovingEntity entity, double time)
	{
		world.put(History.makeTrigger(time, { makeChildEffects(event, entity, time); }, {
				if (event.finished)
					return;
				shootChild(entity);
				makeChildEffects(event, entity, world.now + bulletInterval);
			}, entity.historyID, -1));
	}

	void shootChild(GenericMovingEntity parent)
	{
		parent.edit!((ref parent) {
			vec2 start = parent.read!PositionComponent.position + vec2(0, 16);
			const bvelocity = bullets.velocity;

			if (isNaN(bullets.rotation))
			{
				vec2 direction = vec2(-1, 0);
				editEntity!((ref player) {
					direction = (player.read!PositionComponent.position - start);
				})(controls.player);

				float rot = atan2(direction.y, direction.x);
				float s = sin(rot);
				float c = cos(rot);

				bullets.velocity = mat2(c, -s, s, c) * bvelocity;
			}

			bullets.position = start;
			bullets.build();
			bullets.velocity = bvelocity;
		});
	}

	static GenericEntityBuilder fromFile(in char[] file)
	{
		import std.file : readText;

		return fromJson(parseJSON(readText(file), -1, JSONOptions.specialFloatLiterals));
	}

	static GenericEntityBuilder fromJson(JSONValue json)
	{
		if (json.type != JSONType.object)
			throw new Exception("entity builder file must be a json object");

		GenericEntityBuilder ret = new GenericEntityBuilder();
		foreach (key, value; json.object)
			ret.setJson(key, value);
		return ret;
	}
}

bool readCollisionMask(string property, JSONValue json, ref CollisionComponent.Mask collision)
{
	if (json.type == JSONType.integer)
	{
		collision = cast(CollisionComponent.Mask) json.integer;
		return true;
	}
	else if (json.type == JSONType.string)
	{
		try
		{
			collision = json.str.to!(CollisionComponent.Mask);
			return true;
		}
		catch (ConvException)
		{
			stderr.writefln("'%s' is not a valid %s value. Valid values are: %(%s, %)",
					json.str, property, [__traits(allMembers, CollisionComponent.Mask)]);
			return false;
		}
	}
	else
	{
		stderr.writeln(property, " property only accepts int/string values");
		return false;
	}
}

bool readNumeric(T)(string property, JSONValue json, ref T value)
{
	static if (isFloatingPoint!T)
		bool validFloat = json.type == JSONType.float_;
	else
		enum validFloat = true;

	if (!validFloat && json.type != JSONType.integer && json.type != JSONType.uinteger)
	{
		stderr.writeln(property, " property only accepts numeric values");
		return false;
	}

	if (json.type == JSONType.float_)
		value = cast(T) json.floating;
	else if (json.type == JSONType.integer)
		value = cast(T) json.integer;
	else if (json.type == JSONType.uinteger)
		value = cast(T) json.uinteger;
	else
		assert(false, "didn't expect to get non float/integer/uinteger here");
	return true;
}

bool readVector(int N)(string name, JSONValue json, ref Vector!(float, N) dst)
{
	if (json.type != JSONType.array)
	{
		stderr.writeln(name, " property only accepts array values");
		return false;
	}

	if (json.array.length != N)
	{
		stderr.writeln(name, " property expected ", N, "-size array but got ",
				json.array.length, "-size array");
		return false;
	}

	if (!json.array.all!(a => a.type == JSONType.float_ || a.type == JSONType.integer))
	{
		stderr.writeln(name, " property must consist entirely out of numbers");
		return false;
	}

	foreach (i, v; json.array)
	{
		if (v.type == JSONType.float_)
			dst.vector[i] = v.floating;
		else if (v.type == JSONType.integer)
			dst.vector[i] = v.integer;
		else
			assert(false, "Did not expect to get non float/integer value here");
	}

	return true;
}
