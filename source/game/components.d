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
	vec2 originOffset = vec2(1);
	vec4 color = vec4(1);
}

alias GameWorld = World!(PositionComponent, DisplayComponent, ComplexDisplayComponent);

void editEntity(alias callback)(ref GameWorld world, Entity entity)
{
	auto index = world.getEntity(entity);
	if (index >= 0)
		callback(world.entities[index]);
}
