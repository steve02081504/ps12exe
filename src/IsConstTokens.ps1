function IsConstTokens($Tokens) {
	foreach ($Token in $Tokens) {
		switch ($Token.Kind) {
			default { }
			StringExpandable {
				if (!(IsConstTokens $Token.NestedTokens)) {
					return $FALSE
				}
			}
			Variable {
				$SafeVariables = @('true', 'false', 'null', '_', 'this')
				if ($SafeVariables -notcontains $Token.Name) {
					return $FALSE
				}
			}
			Identifier { return $FALSE }
		}
	}
	return $TRUE
}
