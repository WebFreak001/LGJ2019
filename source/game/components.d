module game.components;

import game.world;

import crunch;

import d2d;

struct PositionComponent
{
	vec2 position = vec2(0);
}

struct DisplayComponent
{
	Crunch.Image sprite;
	vec4 color = vec4(1);
	vec2 scale = vec2(1);
}

struct ComplexDisplayComponent
{
	Crunch.Image sprite;
	vec2 scale = vec2(1);
	float rotation = 0;
	DrawOrigin origin = DrawOrigin.middleCenter;
	vec2 originOffset = vec2(0);
	vec4 color = vec4(1);
}

struct CollisionComponent
{
	enum Mask : uint
	{
		none = 0,
		player = 1U << 0,
		enemyGeneric = 1U << 1,

		playerShot = ~Mask.player,
		enemyShot = Mask.player
	}

	struct Circle
	{
		vec2 center = vec2(0);
		float radius = 0;
		uint mask;
	}

	Circle[8] circles;
	Mask type;
	void delegate(ref GameWorld.WorldEntity self, ref GameWorld.WorldEntity other,
			vec2 center, bool second) onCollide;

	bool collides(vec2 offset, mat2 transform, CollisionComponent other,
			vec2 otherOffset, mat2 otherTransform)
	{
		// must be symmetrical collision because we only check if one side collides with the other and not the other way around

		foreach (c; circles)
		{
			if (!(c.radius > 0)) // NaN prevention included
				continue;
			// only radius > 0 here

			const center1 = c.center * transform + offset;

			foreach (o; other.circles)
			{
				if (!(o.radius > 0)) // NaN prevention included
					continue;
				if ((c.mask & other.type) == 0 && (o.mask & type) == 0)
					continue;

				const r = c.radius + o.radius;

				if ((center1 - (o.center * otherTransform + otherOffset)).length_squared <= r * r)
					return true;
			}
		}
		return false;
	}
}

struct HealthComponent
{
	int maxHp = 1, hp = 0;
	double invulnerabilityTime = 0.1;
	double remainingInvulnerabilityTime = 0;
	double remainingHealTime = 0;
	void delegate(ref GameWorld.WorldEntity entity, int dmg) onDamage;

	void gotHit(ref GameWorld.WorldEntity entity, int dmg, bool callback = true)
	{
		if (onDamage && callback)
		{
			if (dmg > 0)
				remainingInvulnerabilityTime = invulnerabilityTime;
			else if (dmg < 0)
				remainingHealTime = invulnerabilityTime;

			onDamage(entity, dmg);
		}
		else
		{
			if (dmg > hp)
				hp = 0;
			else
				hp -= dmg;
		}
	}
}

alias GameWorld = World!(PositionComponent, DisplayComponent,
		ComplexDisplayComponent, CollisionComponent, HealthComponent);

__gshared GameWorld world;

void editEntity(alias callback)(Entity entity)
{
	auto index = world.getEntity(entity);
	if (index >= 0)
		callback(world.entities[index]);
}

enum WindowWidth = 800;
enum WindowHeight = 608;
enum CanvasScale = 2;
enum CanvasWidth = WindowWidth / CanvasScale;
enum CanvasHeight = WindowHeight / CanvasScale;
