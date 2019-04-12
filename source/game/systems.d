module game.systems;

import d2d;

import crunch;

import resources;

import game.components;
import game.world;
import game.entities.bullet;

import std.algorithm;
import std.meta;
import std.stdio;

struct Controls
{
	Entity player;

	SDL_Keycode leftKey = SDLK_LEFT;
	SDL_Keycode upKey = SDLK_UP;
	SDL_Keycode rightKey = SDLK_RIGHT;
	SDL_Keycode downKey = SDLK_DOWN;

	SDL_Keycode shootKey = SDLK_x;
	double shootCooldown = 0.2; // seconds
	double speed = 200;

	SDL_Keycode warpKey = SDLK_LSHIFT;
	double maxWarpSeconds = 8;
	double warpSecondsLeft = 8;
	double warpRegenSpeed = 0.4; // should be less than -1/warpSpeed so we can't go back further with each regen
	bool warping;
	double warpAcceleration = 0.7; // goes this many percent towards target warp speed every second
	double unwarpAcceleration = 0.98; // goes this many percent towards normal speed every second
	double warpSpeed = -2;
	double warpEmptySpeed = 0.5; // make everything at least run at half time at the cost of not being able to rewind

	// Debug
	SDL_Keycode speedUpKey = SDLK_k;
	SDL_Keycode speedDownKey = SDLK_j;

	double cooldown = 0;
	double warpTimeLeft = 0;

	void handleEvent(ref GameWorld world, Event event)
	{
		if (event.type == Event.Type.KeyPressed && event.key == shootKey)
			shoot(world);
		if (event.type == Event.Type.KeyPressed && event.key == speedUpKey)
		{
			world.normalSpeed += 0.25f;
			writeln("World speed up (", world.normalSpeed, ")");
		}
		if (event.type == Event.Type.KeyPressed && event.key == speedDownKey)
		{
			world.normalSpeed -= 0.25f;
			writeln("World speed down (", world.normalSpeed, ")");
		}
	}

	void update(ref GameWorld world, double delta, double deltaWorld)
	{
		double movementSpeed = max(0.5, min(2, world.speed));
		if (world.speed > 0)
			cooldown -= deltaWorld;

		warping = Keyboard.instance.isPressed(warpKey);

		if (warping)
		{
			if (warpSecondsLeft > 0)
			{
				// https://stackoverflow.com/questions/2666339/modifying-multiplying-calculation-to-use-delta-time
				world.speed = (world.speed - warpSpeed) * pow(1 - warpAcceleration, delta) + warpSpeed;
			}
			else
			{
				world.speed = (world.speed - warpEmptySpeed) * pow(1 - unwarpAcceleration,
						delta) + warpEmptySpeed;
			}
			warpSecondsLeft = max(warpSecondsLeft - delta, 0);
		}
		else
		{
			if (warpSecondsLeft < maxWarpSeconds)
				warpSecondsLeft = min(warpSecondsLeft + delta * warpRegenSpeed, maxWarpSeconds);
			// ease back to normal speed
			world.speed = (world.speed - world.normalSpeed) * pow(1 - unwarpAcceleration,
					delta) + world.normalSpeed;
		}

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
				entity.force!PositionComponent.position.moveClamp(
					movement.normalized * speed * delta * movementSpeed, vec2(400, 304));
			})(player);
		}
	}

	void shoot(ref GameWorld world)
	{
		if (cooldown > 0)
			return;
		cooldown = shootCooldown;

		vec2 start = world.entities[world.getEntity(player)].read!PositionComponent.position + vec2(0,
				16);

		//dfmt off
		new QuadraticBulletEntity(R.sprites.torpedo, vec2(600, 0), vec2(1), vec4(1, 1, 1, 1))
				.addCircle(CollisionComponent.Mask.playerShot, vec2(-12, 0), 4)
				.addCircle(CollisionComponent.Mask.playerShot, vec2(-6, 0), 4)
				.addCircle(CollisionComponent.Mask.playerShot, vec2(6, 0), 4)
				.addCircle(CollisionComponent.Mask.playerShot, vec2(12, 0), 4)
				.create(world, start, 0, 2);
		//dfmt on
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

	Color bg = Color.fromRGB(0x222034);

	void load()
	{
		spriteBatch = new SpriteBatch();
	}

	void draw(ref GameWorld world, IRenderTarget window, ref Controls controls)
	{
		spriteBatch.begin(R.spritesheet.textures[0]);

		int gridSize;
		gridSize = 64;
		foreach(x; 0 .. 800 / gridSize)
			foreach(y; 0 .. 604 / gridSize)
			{
				vec2 position = vec2(x - (world.now % 2), y); // 2 seems to be enough
				Crunch.Image sprite;
				immutable int xMod = x % 2;
				immutable int yMod = y % 2;
				if (xMod == 0 && yMod == 0)
					sprite = R.sprites.city_layer4_0;
				else if (xMod == 1 && yMod == 0)
					sprite = R.sprites.city_layer4_1;
				else if (xMod == 0 && yMod == 1)
					sprite = R.sprites.city_layer4_2;
				else if (xMod == 1 && yMod == 1)
					sprite = R.sprites.city_layer4_3;
				drawBG(sprite, position, gridSize);
			}

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

		drawUI(window, controls);

		spriteBatch.end();
		spriteBatch.draw(window);
	}

	void drawUI(IRenderTarget window, ref Controls controls)
	{
		spriteBatch.drawSprite(R.sprites.white4x, vec2(0, 0),
				vec2(100 * controls.warpSecondsLeft / controls.maxWarpSeconds, 2));
	}
	
	void drawBG(Crunch.Image sprite, vec2 position, int gridSize) {
		spriteBatch.drawSprite(sprite, position * gridSize);
	}
}
