<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="index.aspx.cs" Inherits="ps12exeOnlineMain" Async="true" %>

<!DOCTYPE html>
<meta charset="utf-8" />
<meta name="title" content="ps12exe Online" />
<meta name="description" content="A super cool online compiler for powershell scripts" />
<meta property="og:image" content="https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6" />
<meta property="og:image:alt" content="A super cool online compiler for powershell scripts" />
<meta property="og:type" content="object" />
<meta property="og:title" content="ps12exe Online" />
<meta property="og:description" content="A super cool online compiler for powershell scripts" />
<html>

<head>
	<title>ps12exe Online</title>
	<link rel="icon" type="image/x-icon" href="favicon.ico" />
	<script src='https://www.midijs.net/lib/midi.js'></script>
	<script src="https://cdn.jsdelivr.net/npm/darkreader"></script>
	<script>
		DarkReader.setFetchMethod(window.fetch)
		DarkReader.enable()
		var HighlightCode;
		function SetDarkMode(Set) {
			if (Set) DarkReader.enable()
			else DarkReader.disable()
			HighlightCode.useTheme(Set ? 'github-dark' : 'github')
		}
		(async ({ chrome, netscape }) => {
			if (!chrome && !netscape) await import('https://cdn.jsdelivr.net/npm/@ungap/custom-elements')
			HighlightCode = await import('https://cdn.jsdelivr.net/npm/highlighted-code/min.js').then(x => x.default)
			var dark = window.matchMedia('(prefers-color-scheme: dark)');
			SetDarkMode(dark.matches)
			dark.addEventListener('change', event => {
				SetDarkMode(event.matches)
			})
		})(self)
	</script>
</head>

<body>
	<form id="MainForm" runat="server">
		<textarea runat="server" id="inputText" style="width: 98%; height:95vh;" is="highlighted-code" language="powershell" tabSize="4" placeholder="#_pragma noConsole
'Hello 世界！👾'
">#_pragma noConsole
'Hello 世界！👾'
</textarea>
		<br />
		<asp:Button runat="server" ID="compileButton" OnClick="compileCode" Text="cum out"/>
	</form>
	<script type="text/javascript">
		const userInput = document.getElementById("inputText")
		var playing = false
		userInput.addEventListener("focus", event => {
			if (playing) MIDIjs.resume()
			else MIDIjs.play('./bgm.mid', true)
			playing = true;
		})
		userInput.addEventListener("blur", event => MIDIjs.pause())
	</script>
</body>

</html>
