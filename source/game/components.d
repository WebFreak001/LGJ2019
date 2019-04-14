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
}

alias GameWorld = World!(PositionComponent, DisplayComponent, ComplexDisplayComponent, CollisionComponent);

void editEntity(alias callback)(ref GameWorld world, Entity entity)
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
