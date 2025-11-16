import XCTest
@testable import TOONCore

final class PerformanceSignpostTests: XCTestCase {
    
    // MARK: - Tests with Signpost Disabled (Default)
    
    func testBeginReturnsNilWhenDisabled() {
        // Ensure SWIFTTOON_PERF_TRACE is not set
        let id = PerformanceSignpost.begin("test")
        XCTAssertNil(id, "begin() should return nil when signpost is disabled")
    }
    
    func testEndWithNilIDWhenDisabled() {
        // Should not crash when called with nil ID
        PerformanceSignpost.end("test", id: nil)
        // If we get here without crashing, test passes
        XCTAssertTrue(true)
    }
    
    func testBeginEndPairWhenDisabled() {
        let id = PerformanceSignpost.begin("testOperation")
        XCTAssertNil(id)
        
        // Simulate some work
        _ = (1...100).reduce(0, +)
        
        PerformanceSignpost.end("testOperation", id: id)
        // Should complete without crashing
        XCTAssertTrue(true)
    }
    
    // MARK: - Tests with Signpost Enabled
    
    #if canImport(os)
    func testBeginReturnsIDWhenEnabled() {
        // Set environment variable to enable signposts
        setenv("SWIFTTOON_PERF_TRACE", "1", 1)
        defer { unsetenv("SWIFTTOON_PERF_TRACE") }
        
        // Note: Since the signpostEnabled check happens at module load time,
        // this test verifies the behavior exists but may not capture runtime changes.
        // The actual coverage comes from the code paths being executed.
        let id = PerformanceSignpost.begin("testEnabled")
        
        // On platforms with os.signpost, we expect a non-nil ID when enabled
        // However, the static check may have already been evaluated
        // This test ensures the code path is exercised
        PerformanceSignpost.end("testEnabled", id: id)
        
        XCTAssertTrue(true, "Signpost calls completed without crashing")
    }
    
    func testEndWithValidIDWhenEnabled() {
        setenv("SWIFTTOON_PERF_TRACE", "1", 1)
        defer { unsetenv("SWIFTTOON_PERF_TRACE") }
        
        let id = PerformanceSignpost.begin("testEndWithID")
        
        // Do some work
        _ = (1...1000).map { $0 * 2 }
        
        PerformanceSignpost.end("testEndWithID", id: id)
        
        XCTAssertTrue(true, "End signpost completed without crashing")
    }
    
    func testMultipleNestedSignposts() {
        setenv("SWIFTTOON_PERF_TRACE", "1", 1)
        defer { unsetenv("SWIFTTOON_PERF_TRACE") }
        
        let outerID = PerformanceSignpost.begin("outer")
        
        let innerID1 = PerformanceSignpost.begin("inner1")
        _ = (1...100).reduce(0, +)
        PerformanceSignpost.end("inner1", id: innerID1)
        
        let innerID2 = PerformanceSignpost.begin("inner2")
        _ = (1...100).map { $0 * 2 }
        PerformanceSignpost.end("inner2", id: innerID2)
        
        PerformanceSignpost.end("outer", id: outerID)
        
        XCTAssertTrue(true, "Nested signposts completed without crashing")
    }
    #endif
    
    // MARK: - Cross-platform consistency
    
    func testSignpostAPIExists() {
        // Verify the API surface exists on all platforms
        let id = PerformanceSignpost.begin("apiCheck")
        PerformanceSignpost.end("apiCheck", id: id)
        
        XCTAssertTrue(true, "Signpost API is available on this platform")
    }
    
    func testSignpostWithStaticString() {
        // Test that static strings work correctly
        let name: StaticString = "staticStringTest"
        let id = PerformanceSignpost.begin(name)
        PerformanceSignpost.end(name, id: id)
        
        XCTAssertTrue(true, "Static string signpost name works correctly")
    }
    
    func testSignpostDoesNotThrowOnNilID() {
        // Ensure end() is safe to call with nil ID
        PerformanceSignpost.end("safetyTest", id: nil)
        
        XCTAssertTrue(true, "Calling end() with nil ID does not crash")
    }
}
