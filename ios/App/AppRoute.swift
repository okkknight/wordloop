enum AppRoute: Equatable {
    case designSystemGallery
    case fixtureStudy
    case liveStudy
    case startup
}

enum AppRouteResolver {
    static func resolve(arguments: [String]) -> AppRoute {
        if arguments.contains("-wordloop-design-system-gallery") {
            return .designSystemGallery
        }
        if arguments.contains("-wordloop-study-shell") {
            return .fixtureStudy
        }
        if arguments.contains("-wordloop-live-study") {
            return .liveStudy
        }
        return .startup
    }
}
