# .----------------------------------------------------------------------------.
# |:::    :::     :::     :::        ::::::::  :::   :::  ::::::::  ::::    :::|
# |:+:    :+:   :+: :+:   :+:       :+:    :+: :+:   :+: :+:    :+: :+:+:   :+:|
# |+:+    +:+  +:+   +:+  +:+       +:+         +:+ +:+  +:+    +:+ :+:+:+  +:+|
# |+#++:++#++ +#++:++#++: +#+       +#+          +#++:   +#+    +:+ +#+ +:+ +#+|
# |+#+    +#+ +#+     +#+ +#+       +#+           +#+    +#+    +#+ +#+  +#+#+#|
# |#+#    #+# #+#     #+# #+#       #+#    #+#    #+#    #+#    #+# #+#   #+#+#|
# |###    ### ###     ### ########## ########     ###     ########  ###    ####|
# '----------------------------------------------------------------------------'
# Developer Console
#
# Developed by:
# - Liam Maga
# - 
# - 
# .----------------------------------------------------------------------------.

extends Resource

class_name CursorSettings

## Whether the cursor should be locked by default when the game starts
@export var locked_by_default: bool = true

## List of scene paths that should always show the cursor
@export var always_visible_scenes: Array[String] = []

## Whether pressing Escape should toggle cursor visibility in debug builds
@export var enable_escape_toggle: bool = true

## Custom cursor texture (optional)
@export var custom_cursor: Texture2D = null

## Optional hotspot offset for custom cursor
@export var cursor_hotspot: Vector2 = Vector2(0, 0)

## Whether to force cursor visibility regardless of other settings
@export var force_visibility: bool = false 