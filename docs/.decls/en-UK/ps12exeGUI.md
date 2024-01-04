---
external help file: ps12exe-help.xml
Module Name: ps12exe
online version:
schema: 2.0.0
---

# ps12exeGUI

## SYNOPSIS
ps12exeGUI is a GUI tool for ps12exe.

## SYNTAX

```
ps12exeGUI [[-ConfingFile] <String>] [[-Localize] <String>] [[-UIMode] <String>] [-help]
 [-ProgressAction <ActionPreference>] [<CommonParameters>]
```

## DESCRIPTION
ps12exeGUI is a GUI tool for ps12exe.

## EXAMPLES

### EXAMPLE 1
```
ps12exeGUI -Localize 'en-UK' -UIMode 'Light'
```

### EXAMPLE 2
```
ps12exeGUI -ConfingFile 'ps12exe.json' -Localize 'en-UK' -UIMode 'Dark'
```

### EXAMPLE 3
```
ps12exeGUI -help
```

## PARAMETERS

### -ConfingFile
The path of the configuration file.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 1
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -Localize
The language code to use.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 2
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### -UIMode
The UI mode to use.

```yaml
Type: String
Parameter Sets: (All)
Aliases:

Required: False
Position: 3
Default value: Auto
Accept pipeline input: False
Accept wildcard characters: False
```

### -help
Show this help message.

```yaml
Type: SwitchParameter
Parameter Sets: (All)
Aliases:

Required: False
Position: Named
Default value: False
Accept pipeline input: False
Accept wildcard characters: False
```

### -ProgressAction
{{ Fill ProgressAction Description }}

```yaml
Type: ActionPreference
Parameter Sets: (All)
Aliases: proga

Required: False
Position: Named
Default value: None
Accept pipeline input: False
Accept wildcard characters: False
```

### CommonParameters
This cmdlet supports the common parameters: -Debug, -ErrorAction, -ErrorVariable, -InformationAction, -InformationVariable, -OutVariable, -OutBuffer, -PipelineVariable, -Verbose, -WarningAction, and -WarningVariable. For more information, see [about_CommonParameters](http://go.microsoft.com/fwlink/?LinkID=113216).

## INPUTS

## OUTPUTS

## NOTES

## RELATED LINKS
