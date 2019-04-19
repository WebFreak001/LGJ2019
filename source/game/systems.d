module game.systems;

debug = History;

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

	void handleEvent(Event event)
	{
		if (event.type == Event.Type.KeyPressed && event.key == shootKey)
			shoot();
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

	void update(double delta, double deltaWorld)
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
			shoot();

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
			editEntity!((ref entity) {
				entity.force!PositionComponent.position.moveClamp(movement.normalized * speed * delta * movementSpeed,
					vec2(CanvasWidth, CanvasHeight));
			})(player);
		}
	}

	void shoot()
	{
		if (cooldown > 0)
			return;
		cooldown = shootCooldown;

		vec2 start = world.entities[world.getEntity(player)].read!PositionComponent.position + vec2(0,
				16);

		//dfmt off
		new QuadraticBulletEntity(R.sprites.torpedo, vec2(600, 0), vec2(1), vec4(1, 1, 1, 1))
				.maxHealth(1)
				.addCircle(CollisionComponent.Mask.playerShot, vec2(-12, 0), 4)
				.addCircle(CollisionComponent.Mask.playerShot, vec2(-6, 0), 4)
				.addCircle(CollisionComponent.Mask.playerShot, vec2(6, 0), 4)
				.addCircle(CollisionComponent.Mask.playerShot, vec2(12, 0), 4)
				.create(start, 0, 2);
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

	void draw(IRenderTarget window, ref Controls controls)
	{
		spriteBatch.begin(R.spritesheet.textures[0]);

		drawBG();

		foreach (ref entity; world.entities)
		{
			if (entity.entity.dead)
				continue;

			PositionComponent position = entity.read!PositionComponent; // or default
			DisplayComponent img = entity.read!DisplayComponent;

			float height = 16;

			if (img !is DisplayComponent.init)
			{
				spriteBatch.drawSprite(img.sprite, position.position, img.color);
				height = img.sprite.height;
			}

			ComplexDisplayComponent cimg = entity.read!ComplexDisplayComponent;
			if (cimg !is ComplexDisplayComponent.init)
			{
				spriteBatch.drawSprite(cimg.sprite, position.position, cimg.scale,
						cimg.rotation, cimg.origin, cimg.originOffset, cimg.color);
				height = cimg.sprite.height;
			}

			auto hp = entity.get!HealthComponent;
			if (hp && hp.maxHp > 1)
			{
				float percent = hp.hp / cast(float) hp.maxHp;

				spriteBatch.drawSprite(R.sprites.white, position.position + vec2(-8,
						height * 0.75f), vec2(16, 2), vec4(1, 0, 0, 1));
				spriteBatch.drawSprite(R.sprites.white, position.position + vec2(-8,
						height * 0.75f), vec2(16 * percent, 2), vec4(0, 1, 0, 1));
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

		debug (History)
		{
			enum timewidth = 35.0f; // 40 is full width

			spriteBatch.drawSprite(R.sprites.white4x, vec2(0, 8), vec2(100, 2), vec4(0, 0, 0, 1));
			spriteBatch.drawSprite(R.sprites.white4x, vec2(timewidth * (world.now % 10), 8),
					vec2(0.25f, 2), vec4(0, 0, 1, 1));
			double start = floor(world.now / 10) * 10;
			double end = start + 10;
			foreach (i, event; world.events)
			{
				if (event.start < start || event.start > end)
					continue;

				double x = event.start - start;

				vec3 color = event.finished ? vec3(0, 1, 0) : vec3(1, 0, 0);
				spriteBatch.drawSprite(R.sprites.white4x, vec2(timewidth * x, 8),
						vec2(0.25f, 2), vec4(color, 0.7f));
				spriteBatch.drawSprite(R.sprites.white4x, vec2(timewidth * x, 8),
						vec2(timewidth * 0.25f * (event.end - event.start), 0.5f), vec4(color, 0.4f));
				if (!isNaN(event.ended))
				{
					spriteBatch.drawSprite(R.sprites.white4x, vec2(timewidth * (event.ended - start), 8),
							vec2(0.5f, 1), vec4(1, 1, 0, 0.6f));
				}

				if (i == world.eventStartIndex)
				{
					spriteBatch.drawSprite(R.sprites.white4x, vec2(timewidth * x - 2,
							14), vec2(0.5f, 0.5f), vec4(0, 1, 0, 1));
				}

				if (i + 1 == world.eventEndIndex)
				{
					spriteBatch.drawSprite(R.sprites.white4x, vec2(timewidth * x, 14),
							vec2(0.5f, 0.5f), vec4(0, 0, 1, 1));
				}
			}
		}
	}

	void drawBG()
	{
		int gridSize;
		vec2i dimensions;

		// Stars
		gridSize = 64;
		//dfmt off
		Crunch.Image[4] tileset1 = [
			R.sprites.city_layer4_0,
			R.sprites.city_layer4_1,
			R.sprites.city_layer4_2,
			R.sprites.city_layer4_3
		];
		size_t[4] bitmap1 = [0, 1, 2, 3];
		//dfmt on
		dimensions = vec2i(2, 2);
		drawBGLayer(tileset1[], bitmap1[], dimensions, gridSize,
				vec2(-world.now * 4, -world.now * 0.2f));

		// Buildings
		gridSize = 16;
		//dfmt off
		Crunch.Image[3 * 4] tileset2 = [
			R.sprites.city_layer1_0, R.sprites.city_layer1_1, R.sprites.city_layer1_2,
			R.sprites.city_layer1_3, R.sprites.city_layer1_4, R.sprites.city_layer1_5,
			R.sprites.city_layer1_6, R.sprites.city_layer1_7, R.sprites.city_layer1_8,
			R.sprites.city_layer1_9, R.sprites.city_layer1_10, R.sprites.city_layer1_11
		];
		size_t[18 * 6] bitmap2 = [
			0,1,2, 3,0,0, 0,0,0,0, 0,0,0, 0,0,0,0,0,
			4,6,6, 7,0,0, 0,0,0,0, 0,0,0, 0,0,0,0,0,
			4,6,6, 7,0,0, 0,0,0,0, 0,0,0, 0,0,0,1,3,
			4,6,6, 7,0,0, 0,1,2,3, 0,1,3, 0,1,8,6,7,
			4,6,6,11,2,3, 4,5,5,7, 4,6,7, 4,5,6,6,7,
			4,6,6, 9,6,7, 4,6,9,7, 4,9,7, 4,6,6,6,7
		];
		//dfmt on
		dimensions = vec2i(18, 6);
		drawBGLayer(tileset2[], bitmap2[], dimensions, gridSize,
				vec2(-world.now * 32, 0), vec2(0, 208 + 6 * 16));
	}

	/// Draws a tiling background with set scroll. Starts drawing at -dimensions and not at 0
	void drawBGLayer(scope const Crunch.Image[] tileset, scope const size_t[] bitmap,
			vec2i dimensions, int gridSize, vec2 scroll, vec2 offset = vec2(0))
	{
		immutable drawWidth = CanvasWidth / gridSize;
		immutable drawHeight = CanvasHeight / gridSize;

		immutable chunkWidth = dimensions.x * gridSize;
		immutable chunkHeight = dimensions.y * gridSize;

		scroll.x = scroll.x % chunkWidth;
		scroll.y = scroll.y % chunkHeight;

		for (int y = -dimensions.y; y <= drawHeight + dimensions.y; y++)
			for (int x = -dimensions.x; x <= drawWidth + dimensions.x; x++)
			{
				vec2 position = vec2(x * gridSize, y * gridSize) + scroll + offset;

				immutable xMod = (x + dimensions.x) % dimensions.x;
				immutable yMod = (y + dimensions.y) % dimensions.y;
				immutable index = xMod + yMod * dimensions.x;
				spriteBatch.drawSprite(tileset[bitmap[index]], position);
			}
	}
}

struct CollisionSystem
{
	void update(double deltaWorld)
	{
		foreach (i, ref entity; world.entities)
		{
			if (entity.entity.dead)
				continue;

			auto hp = entity.get!HealthComponent;
			if (hp)
			{
				if (hp.remainingInvulnerabilityTime <= 0)
					hp.remainingInvulnerabilityTime = 0;
				else
					hp.remainingInvulnerabilityTime -= abs(deltaWorld);

				if (hp.remainingHealTime <= 0)
					hp.remainingHealTime = 0;
				else
					hp.remainingHealTime -= abs(deltaWorld);
			}

			auto collider = entity.get!CollisionComponent;
			if (!collider)
				continue;
			PositionComponent position = entity.read!PositionComponent; // or default

			foreach (ref other; world.entities[i + 1 .. $])
			{
				if (other.entity.dead)
					continue;

				auto otherCollider = other.get!CollisionComponent;
				if (!otherCollider)
					continue;
				PositionComponent otherPosition = other.read!PositionComponent; // or default

				if (collider.collides(position.position, *otherCollider, otherPosition.position))
				{
					auto center = (position.position + otherPosition.position) * 0.5f;
					if (collider.onCollide)
						collider.onCollide(entity, other, center, false);
					else
						defaultCollisionCallback(entity, other, center, false);

					if (otherCollider.onCollide)
						otherCollider.onCollide(other, entity, center, true);
					else
						defaultCollisionCallback(other, entity, center, true);
				}
			}
		}
	}
}

void defaultCollisionCallback(ref GameWorld.WorldEntity self,
		ref GameWorld.WorldEntity other, vec2 center, bool second)
{
	auto selfHp = self.get!HealthComponent;
	auto otherHp = other.get!HealthComponent;

	if (selfHp && otherHp)
	{
		if (selfHp.remainingInvulnerabilityTime <= 0 && otherHp.remainingInvulnerabilityTime <= 0)
		{
			auto hp = min(selfHp.hp, otherHp.hp);
			selfHp.gotHit(self, hp);
			otherHp.gotHit(other, hp);
		}
	}
}
