function IsDisable($value) {
	@('off', 'false', 'N', 'No', 'unset', 0, 'disable', '$false') -contains "$value"
}

function IsEnable($value) {
	@('on', 'true', 'Y', 'Yes', 'set', 1, 'enable', '$true') -contains "$value"
}
