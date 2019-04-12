module game.entities.bullet;

import d2d;

import std.math;

import crunch;

import game.components;
import game.world;

abstract class HistoryEntity : IHistory
{
	protected Entity entity;
	protected GameWorld* world;
	protected vec2 start;
	protected double delay, lifeTime;

	void create(ref GameWorld world, vec2 start, double delay, double lifeTime)
	{
		this.world = &world;
		this.start = start;
		this.delay = delay;
		this.lifeTime = lifeTime;

		makeEntity(world, start, delay, lifeTime);
		initializeEntity(world);
		world.put(History.make(world.now + delay, world.now + delay + lifeTime, this));
	}

	protected void makeEntity(ref GameWorld world, vec2 start, double delay, double lifeTime)
	{
		entity = world.putEntity(Dead.yes, PositionComponent(start));
	}

	protected void initializeEntity(ref GameWorld world)
	{
	}

	final void makeDead(bool dead)
	{
		this.edit!((ref entity) { entity.entity.dead = dead; });
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

	protected override void makeEntity(ref GameWorld world, vec2 start, double delay, double lifeTime)
	{
		entity = world.putEntity(Dead.yes, PositionComponent(start),
				ComplexDisplayComponent(sprite, scale, rotation, DrawOrigin.middleCenter, vec2(0), color));
	}
}

private void edit(alias cb)(HistoryEntity he)
{
	(*he.world).editEntity!cb(he.entity);
}

class DirectionalDrawableHistoryEntity(alias interp) : DrawableHistoryEntity
{
	vec2 velocity;
	vec2 end;

	this(Crunch.Image sprite, vec2 velocity, vec2 scale = vec2(1), vec4 color = vec4(1))
	{
		float rotation = atan2(velocity.x, -velocity.y);
		super(sprite, rotation, scale, color);
		this.velocity = velocity;
	}

	override void create(ref GameWorld world, vec2 start, double delay, double lifeTime)
	{
		super.create(world, start, delay, lifeTime);

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
	CollisionComponent.Mask collisionMask;

	this(CollisionComponent.Mask collisionMask, Crunch.Image sprite, vec2 velocity,
			vec2 scale = vec2(1), vec4 color = vec4(1))
	{
		super(sprite, velocity, scale, color);

		this.collisionMask = collisionMask;
	}

	protected override void initializeEntity(ref GameWorld world)
	{
		this.edit!((ref entity) {
			CollisionComponent collision;
			collision.circles[0].mask = collisionMask;
			collision.circles[0].center = vec2(0, 0);
			collision.circles[0].radius = 2 * scale.length;
			entity.write(collision);
		});
	}
}

alias LinearBulletEntity = BulletEntity!LinearDrawableHistoryEntity;
