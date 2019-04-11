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

alias GameWorld = World!(PositionComponent, DisplayComponent);

void editEntity(alias callback)(ref GameWorld world, Entity entity)
{
	auto index = world.getEntity(entity);
	if (index >= 0)
		callback(world.entities[index]);
}
