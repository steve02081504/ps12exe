/* global suite: readonly, test: readonly */
import assert from 'node:assert'

import { parseGalleryEntry, packagePageUrl, tagSearchUrl, isGeneratedTag } from '../lib/gallery.mjs'

const FEED_HEAD = '<?xml version="1.0" encoding="utf-8"?><feed xmlns="http://www.w3.org/2005/Atom" ' +
	'xmlns:d="http://schemas.microsoft.com/ado/2007/08/dataservices" ' +
	'xmlns:m="http://schemas.microsoft.com/ado/2007/08/dataservices/metadata">'

suite('ps12exe PowerShell Gallery entries', () => {
	test('parses the fields, decodes entities and drops generated tags', () => {
		const xml = FEED_HEAD +
			'<entry><m:properties>' +
			'<d:Id>Pester</d:Id>' +
			'<d:Version>5.5.0</d:Version>' +
			'<d:Description>&lt;p&gt;Pester tests &amp; mocks.&lt;/p&gt;</d:Description>' +
			'<d:IconUrl>https://example.com/pester.png</d:IconUrl>' +
			'<d:ProjectUrl>https://github.com/Pester/Pester</d:ProjectUrl>' +
			'<d:GalleryDetailsUrl>https://www.powershellgallery.com/packages/Pester/5.5.0</d:GalleryDetailsUrl>' +
			'<d:Tags>powershell bdd PSFunction_Invoke-Pester PSCommand_Invoke-Pester</d:Tags>' +
			'</m:properties></entry></feed>'

		assert.deepStrictEqual(parseGalleryEntry(xml), {
			id: 'Pester',
			version: '5.5.0',
			description: 'Pester tests & mocks.',
			iconUrl: 'https://example.com/pester.png',
			projectUrl: 'https://github.com/Pester/Pester',
			galleryUrl: 'https://www.powershellgallery.com/packages/Pester/5.5.0',
			tags: ['powershell', 'bdd']
		})
	})

	test('falls back to the module page when the optional fields are null', () => {
		const xml = FEED_HEAD +
			'<entry><m:properties>' +
			'<d:Id>Pester</d:Id>' +
			'<d:Version>5.5.0</d:Version>' +
			'<d:ProjectUrl m:null="true" />' +
			'<d:IconUrl m:null="true" />' +
			'</m:properties></entry></feed>'

		const info = parseGalleryEntry(xml)
		assert.strictEqual(info.projectUrl, '')
		assert.strictEqual(info.iconUrl, '')
		assert.strictEqual(info.galleryUrl, 'https://www.powershellgallery.com/packages/Pester/5.5.0')
	})

	test('returns null when the feed has no entry', () => {
		assert.strictEqual(parseGalleryEntry(`${FEED_HEAD}</feed>`), null)
	})

	test('recognizes the tags the gallery generates', () => {
		assert.strictEqual(isGeneratedTag('PSFunction_Invoke-Pester'), true)
		assert.strictEqual(isGeneratedTag('PSCommand_Invoke-Pester'), true)
		assert.strictEqual(isGeneratedTag('PSIncludes_Function'), true)
		assert.strictEqual(isGeneratedTag('powershell'), false)
		assert.strictEqual(isGeneratedTag('PSEdition_Core'), false)
	})

	test('builds module page and tag search urls', () => {
		assert.strictEqual(packagePageUrl('Pester'), 'https://www.powershellgallery.com/packages/Pester')
		assert.strictEqual(packagePageUrl('Pester', '5.5.0'), 'https://www.powershellgallery.com/packages/Pester/5.5.0')
		assert.strictEqual(
			tagSearchUrl('unit_testing'),
			'https://www.powershellgallery.com/packages?q=Tags%3A%22unit_testing%22'
		)
	})
})
