import WordLoopCore

public actor CourseRepository {
    private let source: any CourseSource
    private var cachedCatalog: CourseCatalog?
    private var cachedCourses: [CourseID: Course] = [:]

    public init(source: any CourseSource) {
        self.source = source
    }

    public func catalog() throws -> CourseCatalog {
        if let cachedCatalog { return cachedCatalog }
        let loaded = try source.loadCatalog()
        cachedCatalog = loaded
        return loaded
    }

    public func descriptors() throws -> [CourseDescriptor] {
        try catalog().courses
    }

    public func course(id: CourseID) throws -> Course {
        if let cached = cachedCourses[id] { return cached }
        let catalog = try catalog()
        guard let descriptor = catalog.courses.first(where: { $0.id == id }) else {
            throw CourseContentError.unknownCourse(id.rawValue)
        }
        let loaded = try source.loadCourse(descriptor: descriptor)
        cachedCourses[id] = loaded
        return loaded
    }
}
