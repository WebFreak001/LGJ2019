module game.systems;

import d2d;

import resources;

import game.components;
import game.world;

import std.meta;

struct DrawSystem
{
	SpriteBatch spriteBatch;

	void load()
	{
		spriteBatch = new SpriteBatch();
	}

	void draw(ref GameWorld world, IRenderTarget window)
	{
		spriteBatch.begin(R.spritesheet.textures[0]);

		spriteBatch.drawSprite(R.sprites.white4x, vec2(0, 0), vec2(100, 304) / 4.0f, vec4(1, 0, 0, 1));
		spriteBatch.drawSprite(R.sprites.white4x, vec2(100, 0), vec2(100,
				304) / 4.0f, vec4(0, 1, 0, 1));
		spriteBatch.drawSprite(R.sprites.white4x, vec2(200, 0), vec2(100,
				304) / 4.0f, vec4(0, 0, 1, 1));
		spriteBatch.drawSprite(R.sprites.white4x, vec2(300, 0), vec2(100,
				304) / 4.0f, vec4(1, 1, 0, 1));

		foreach (ref entity; world.entities)
		{
			if (entity.entity.dead)
				continue;

			PositionComponent position = entity.read!PositionComponent; // or default
			DisplayComponent img = entity.read!DisplayComponent;

			if (img !is DisplayComponent.init)
			{
				spriteBatch.drawSprite(img.sprite, position.position, img.color);
			}
		}

		spriteBatch.end();
		spriteBatch.draw(window);
	}
}
