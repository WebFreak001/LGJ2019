module game.systems;

import d2d;

import resources;

import game.components;
import game.world;

import std.meta;
import std.stdio;

struct Controls
{
	Entity player;

	SDL_Keycode leftKey = SDLK_a;
	SDL_Keycode upKey = SDLK_w;
	SDL_Keycode rightKey = SDLK_d;
	SDL_Keycode downKey = SDLK_s;

	SDL_Keycode shootKey = SDLK_SPACE;
	double shootCooldown = 0.1; // seconds
	double speed = 100;

    // Debug
	SDL_Keycode speedUpKey = SDLK_k;
	SDL_Keycode speedDownKey = SDLK_j;

	double cooldown;

	void handleEvent(ref GameWorld world, Event event)
	{
		if (event.type == Event.Type.KeyPressed && event.key == shootKey)
			shoot(world);
		if (event.type == Event.Type.KeyPressed && event.key == speedUpKey)
		{
            world.speed += 0.25f;
			writeln("World speed up (", world.speed, ")");
		}
		if (event.type == Event.Type.KeyPressed && event.key == speedDownKey)
		{
            world.speed -= 0.25f;
			writeln("World speed down (", world.speed, ")");
		}
	}

	void update(ref GameWorld world, double delta)
	{
		if (delta > 0)
			cooldown -= delta;

		if (Keyboard.instance.isPressed(shootKey))
			shoot(world);

		vec2 movement = vec2(0, 0);
		if (Keyboard.instance.isPressed(leftKey))
			movement += vec2(-1, 0);
		if (Keyboard.instance.isPressed(upKey))
			movement += vec2(0, -1);
		if (Keyboard.instance.isPressed(rightKey))
			movement += vec2(1, 0);
		if (Keyboard.instance.isPressed(downKey))
			movement += vec2(0, 1);

		if (movement !is vec2(0, 0))
		{
			world.editEntity!((ref entity) {
				entity.force!PositionComponent.position.moveClamp(movement.normalized * speed * delta,
					vec2(400, 304));
			})(player);
		}
	}

	void shoot(ref GameWorld world)
	{
		if (cooldown > 0)
			return;
		cooldown = shootCooldown;

		vec2 start = world.entities[world.getEntity(player)].read!PositionComponent.position;

		auto entity = world.putEntity(PositionComponent(vec2(100, 100)),
				DisplayComponent(R.sprites.white4x, vec4(1, 1, 1, 0.5f)));

		world.put(History(world.now, world.now + 2, () {
				writeln("unstart");
				world.editEntity!((ref entity) { entity.entity.dead = true; })(entity);
			}, () {
				writeln("restart");
				world.editEntity!((ref entity) { entity.entity.dead = false; })(entity);
			}, () {
				writeln("finish");
				world.editEntity!((ref entity) { entity.entity.dead = true; })(entity);
			}, () {
				writeln("unfinish");
				world.editEntity!((ref entity) { entity.entity.dead = false; })(entity);
			}, (p, d) {
				world.editEntity!((ref entity) {
					entity.write(PositionComponent(start + vec2(p * 400, 0)));
				})(entity);
			}));
	}
}

private void moveClamp(ref vec2 position, vec2 movement, vec2 clamp)
{
	position += movement;
	if (position.x > clamp.x)
		position.x = clamp.x;
	if (position.y > clamp.y)
		position.y = clamp.y;
	if (position.x < 0)
		position.x = 0;
	if (position.y < 0)
		position.y = 0;
}

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

			ComplexDisplayComponent cimg = entity.read!ComplexDisplayComponent;
			if (cimg !is ComplexDisplayComponent.init)
			{
				spriteBatch.drawSprite(cimg.sprite, position.position, cimg.scale,
						cimg.rotation, cimg.origin, cimg.originOffset, cimg.color);
			}
		}

		spriteBatch.end();
		spriteBatch.draw(window);
	}
}
