module game.entities.bullet;

import d2d;

import std.math;

import crunch;

import game.components;
import game.world;

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
			entity.write(PositionComponent(interp(start, end, progress)));
		});
	}
}

alias LinearDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((start,
		end, t) => (end - start) * t + start);

alias QuadraticDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((start,
		end, t) => (end - start) * t * t + start);

alias CubicDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((start,
		end, t) => (end - start) * t * t * t + start);

alias QuarticDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((start,
		end, t) => (end - start) * t * t * t * t + start);

alias QuinticDrawableHistoryEntity = DirectionalDrawableHistoryEntity!((start,
		end, t) => (end - start) * t * t * t * t * t + start);

class BulletEntity(Base) : Base
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

alias LinearBulletEntity = BulletEntity!LinearDrawableHistoryEntity;
alias QuadraticBulletEntity = BulletEntity!QuadraticDrawableHistoryEntity;
