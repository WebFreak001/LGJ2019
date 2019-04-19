module resources;

import d2d;

import std.exception;

struct Resources
{
	alias usedSprites = AliasSeq!("player", "white", "white2x", "white4x",
			"bullet", "lazer", "torpedo", "city_layer1_0", "city_layer1_1",
			"city_layer1_2", "city_layer1_3", "city_layer1_4",
			"city_layer1_5", "city_layer1_6", "city_layer1_7", "city_layer1_8", "city_layer1_9",
			"city_layer1_10", "city_layer1_11", "city_layer2_0", "city_layer2_1",
			"city_layer2_2", "city_layer2_3", "city_layer2_4", "city_layer2_5",
			"city_layer2_6", "city_layer2_7", "city_layer4_0", "city_layer4_1",
			"city_layer4_2", "city_layer4_3", "ufo");

	Spritesheet spritesheet;
	// magically wraps all the used sprites as easy to access variables
	typeof(spritesheet.buildLookup!usedSprites(0)) sprites;

	void load()
	{
		spritesheet.load("res/spritesheet.bin");
		enforce(spritesheet.textures.length == 1, "Multi-page spritesheets not supported");
		sprites = spritesheet.buildLookup!usedSprites(0);
	}
}

/// All globally accessible resources
__gshared Resources R;
