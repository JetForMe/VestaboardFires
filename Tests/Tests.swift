//
//  Tests.swift
//  Fires
//
//  Created by Rick Mann on 2025-01-13.
//



import Foundation
import Testing


struct
Tests
{
	@Test
	func
	testRelDate()
	{
		let df = RelativeDateTimeFormatter()
		let date = Date(timeIntervalSince1970: 1736607134923.0 / 1000.0)
		print("\(df.string(for: date))")
	}
}
