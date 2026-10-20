import Foundation
import XCTest
@testable import DSHProtocol

final class PhoneFontPreferencesTests: XCTestCase {
    private let roles: [(ThemeFontRole, String, Int)] = [
        (.text, "dsh.fontSize", 16),
        (.code, "dsh.codeFontSize", 13),
        (.terminal, "dsh.terminalFontSize", 14),
    ]

    func testUnconfiguredInstallUsesLargerDefaultsWithoutPersistingThem() {
        withDefaults { defaults, _ in
            for (role, key, expected) in roles {
                XCTAssertNil(defaults.object(forKey: key))
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), expected)
                XCTAssertNil(defaults.object(forKey: key), "Reading a default must not pin it for future upgrades")
            }
        }
    }

    func testUpgradePreservesEveryStoredValueIncludingOldDesktopDefaults() {
        withDefaults { defaults, _ in
            for (role, key, _) in roles {
                let spec = themeFontSizeSpec(role)
                for value in spec.range {
                    defaults.set(value, forKey: key)
                    XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), value)
                    XCTAssertEqual(defaults.integer(forKey: key), value)
                }
                defaults.set(spec.default, forKey: key)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), spec.default)
            }
        }
    }

    func testExplicitChoiceAtNewDefaultPersistsAcrossPreferenceInstances() {
        withDefaults { defaults, suite in
            for (role, key, value) in roles {
                PhoneFontPreferences.setSize(value, for: role, defaults: defaults)
                XCTAssertEqual(defaults.object(forKey: key) as? Int, value)
            }
            let reopened = UserDefaults(suiteName: suite)!
            for (role, _, value) in roles {
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: reopened), value)
            }
        }
    }

    func testEachRoleCanStepBothWaysAndClampsAtExistingBounds() {
        withDefaults { defaults, _ in
            for (role, key, initial) in roles {
                XCTAssertTrue(themeFontSizeCanIncrease(role, value: initial))
                XCTAssertTrue(themeFontSizeCanDecrease(role, value: initial))
                for delta in [-1, 1] {
                    let next = themeFontSizeStepped(role, value: initial, delta: delta)
                    PhoneFontPreferences.setSize(next, for: role, defaults: defaults)
                    XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), initial + delta)
                }
                let range = themeFontSizeSpec(role).range
                PhoneFontPreferences.setSize(-100, for: role, defaults: defaults)
                XCTAssertEqual(defaults.integer(forKey: key), range.lowerBound)
                PhoneFontPreferences.setSize(100, for: role, defaults: defaults)
                XCTAssertEqual(defaults.integer(forKey: key), range.upperBound)
                defaults.set(-100, forKey: key)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), range.lowerBound)
                defaults.set(100, forKey: key)
                XCTAssertEqual(PhoneFontPreferences.size(role, defaults: defaults), range.upperBound)
            }
        }
    }

    func testChangingOneRoleDoesNotMaterializeOtherDefaultsOrHostPreferences() {
        withDefaults { defaults, suite in
            PhoneFontPreferences.setSize(18, for: .text, defaults: defaults)
            XCTAssertEqual(defaults.persistentDomain(forName: suite)?.count, 1)
            XCTAssertEqual(defaults.integer(forKey: "dsh.fontSize"), 18)
            XCTAssertNil(defaults.object(forKey: "dsh.codeFontSize"))
            XCTAssertNil(defaults.object(forKey: "dsh.terminalFontSize"))
            defaults.removeObject(forKey: "dsh.fontSize")
            XCTAssertEqual(PhoneFontPreferences.size(.text, defaults: defaults), 16)
            XCTAssertNil(defaults.object(forKey: "dsh.fontSize"))
        }
    }

    private func withDefaults(_ body: (UserDefaults, String) -> Void) {
        let suite = "PhoneFontPreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        body(defaults, suite)
    }
}
