/** @param {import('@types/github-script').AsyncFunctionArguments} AsyncFunctionArguments */
module.exports = async ({ github, context }) => {
	const issueBody = context.payload.issue.body.toLowerCase();
	var keywords = [
		'high-risk', 'sandbox', '沙箱', '生成恶意', 'anti-virus', 'antivirus', 'malware', '杀软', '杀毒', '病毒' , '木马', '安全引擎', 'Win32/Trojan'
	]
	if (keywords.some(keyword => issueBody.includes(keyword))) {
		const issueNumber = context.payload.issue.number;
		const issueOwnerId = context.payload.issue.user.login;
		const CommentBody = "嗨"+issueOwnerId+"！\n\
收到你的反馈啦！谢谢你的宝贵意见！👌\n\
Hi "+issueOwnerId+"!\n\
Thanks for your feedback! I really appreciate it!👌\n\
\n\
首先要说明的是，**ps12exe本身没有任何恶意代码哦**。之所以被标记为高危，是因为曾经有坏人用PowerShell脚本生成恶意代码，所以现在杀毒软件会对这类文件比较敏感。🥹\n\
**ps12exe是一个纯脚本模块**，你可以随时查看它的源代码，确认它没有任何安全问题。\n如果你还是不放心dll文件依赖，可以从官方项目下载对应文件，替换`src/bin`文件夹中的同名文件即可。\n\
First of all, I want to let you know that **ps12exe does NOT contain any malicious code**. It's been flagged as high risk because some bad guys used PowerShell scripts to create malware in the past, so antivirus software is now more sensitive to this type of file. 🥹\n\
**ps12exe is a pure script module**, which means you can always check its source code to make sure it's safe.\n\
If you're still not sure about the dll file dependencies, you can download the corresponding files from the official project and replace the ones in the `src/bin` folder.\n\
\n\
如果你的exe文件被误报，咱觉得最可靠的方法是向杀毒软件厂商进行申诉，帮助他们把你的exe文件从高危名单中移除。🐛\n\
If your exe file is falsely flagged, I think the best way to get rid of it is report to the antivirus software company and help them remove your exe from the high-risk list. 🐛\n\
\n\
你或许还会想试试使用自签名证书对你的exe文件进行签名，这在某些情况下会有用。🔐\n\
You may try signing your exe file with a self-signed certificate, which will be useful in some cases. 🔐\n\
（代码来自[brandoncomputer](https://github.com/steve02081504/ps12exe/issues/10#issuecomment-2119018566)）\n\
(code from [brandoncomputer](https://github.com/steve02081504/ps12exe/issues/10#issuecomment-2119018566))\n\
\n\
```powershell\n\
New-SelfSignedCertificate -DnsName email@email.com -Type CodeSigning -CertStoreLocation cert:\\CurrentUser\\My\n\
Export-Certificate -Cert (Get-ChildItem Cert:\\CurrentUser\\My -CodeSigningCert)[0] -FilePath code_signing.crt\n\
Import-Certificate -FilePath .\\code_signing.crt -Cert Cert:\\CurrentUser\\TrustedPublisher\n\
Import-Certificate -FilePath .\\code_signing.crt -Cert Cert:\\CurrentUser\\Root\n\
Set-AuthenticodeSignature 'c:\\myexe\\myexe.exe' -Certificate (Get-ChildItem Cert:\\CurrentUser\\My -CodeSigningCert)\n\
```\n\
\n\
最后，再次感谢你的反馈！\n\
这个commit是由咱自动判断issue内容并自动回复的，存在误判的可能。不用担心，如果还有任何疑问，随时可以重新打开这个issue，我会一直在这里哒！😜\n\
Finally, thanks again for your feedback!\n\
This commit is auto judged by me and auto replied, there may be mistakes. But don't worry, if you have any other questions, feel free to reopen this issue, I'll always be here! 😜\n\
\n\
祝你每天都开开心心，像吃了蜜一样甜！🥰\n\
Hope you have a sweet and lovely day! 🥰\n\
"
		await github.rest.issues.createComment({
			owner: context.repo.owner,
			repo: context.repo.repo,
			issue_number: issueNumber,
			body: CommentBody,
		});
		await github.rest.issues.update({
			owner: context.repo.owner,
			repo: context.repo.repo,
			issue_number: issueNumber,
			state: 'closed',
		});
	}
}
