import d2d;

import resources;

import game.components;
import game.systems;
import game.world;

class Game1 : Game
{
private:
	bool paused;
	GameWorld world;

	Controls controls;
	DrawSystem drawSystem;

protected:
	override void onEvent(Event event)
	{
		super.onEvent(event);

		controls.handleEvent(world, event);
	}

public:

	override void start()
	{
		windowWidth = 800;
		windowHeight = 608;
		windowTitle = "LGJ2019";
		maxFPS = 120;
	}

	override void load()
	{
		R.load();
		drawSystem.load();

		controls.player = world.putEntity(PositionComponent(vec2(200, 152)),
				ComplexDisplayComponent(R.sprites.player));
	}

	override void update(float delta)
	{
		if (paused)
			return;

		world.update(delta);

		double deltaWorld = delta * world.speed;

		controls.update(world, delta, deltaWorld);
	}

	override void draw()
	{
		window.clear(0, 0, 0);
		matrixStack.top = mat4.scaling(2, 2, 2);
		// screen size is 400x304 now

		drawSystem.draw(world, window);
	}
}

void main()
{
	new Game1().run();
}
