import { strictEqual } from 'assert'

// You can import and use all API from the 'vscode' module
// as well as import your extension to test it
import { window } from 'vscode'

suite('Extension Test Suite', () => {
	window.showInformationMessage('Start all tests.')

	test('Sample test', () => {
		strictEqual(-1, [1, 2, 3].indexOf(5))
		strictEqual(-1, [1, 2, 3].indexOf(0))
	})
})
