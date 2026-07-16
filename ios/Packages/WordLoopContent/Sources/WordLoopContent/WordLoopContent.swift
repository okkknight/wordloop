import WordLoopCore

/// Compile-time marker for the WordLoopContent module boundary.
public enum WordLoopContentModule {
    public static let name = "WordLoopContent"
}

public protocol CourseSource: Sendable {
    func loadCatalog() throws -> CourseCatalog
    func loadCourse(descriptor: CourseDescriptor) throws -> Course
}

public enum CourseValidationMode: Sendable {
    case lightweight
    case full
}
