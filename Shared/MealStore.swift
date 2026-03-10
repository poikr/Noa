import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

@Observable
class MealStore {
    static let shared = MealStore()
    static let mealsKey = "cached_meals"
    static let mealsFetchDateKey = "meals_fetch_date"
    static let apiKeyKey = "neis_api_key"
    static let schoolInfoKey = "neis_school_info"

    var todayMeals: [MealInfo] = []
    var isLoading = false
    var errorMessage: String?
    var lastFetchDate: String?
    var apiKey: String {
        didSet { Self.sharedDefaults?.set(apiKey, forKey: Self.apiKeyKey) }
    }
    var selectedSchool: SchoolInfo? {
        didSet {
            if let school = selectedSchool,
               let data = try? JSONEncoder().encode(school) {
                Self.sharedDefaults?.set(data, forKey: Self.schoolInfoKey)
            } else {
                Self.sharedDefaults?.removeObject(forKey: Self.schoolInfoKey)
            }
        }
    }

    private static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: TimetableStore.appGroupID)
    }

    private init() {
        let defaults = Self.sharedDefaults
        self.apiKey = defaults?.string(forKey: Self.apiKeyKey) ?? ""
        if let data = defaults?.data(forKey: Self.schoolInfoKey),
           let school = try? JSONDecoder().decode(SchoolInfo.self, from: data) {
            self.selectedSchool = school
        } else {
            self.selectedSchool = nil
        }
        self.lastFetchDate = defaults?.string(forKey: Self.mealsFetchDateKey)
        loadCachedMeals()
    }

    var isConfigured: Bool {
        !apiKey.isEmpty && selectedSchool != nil
    }

    // MARK: - Caching

    private func loadCachedMeals() {
        let today = NEISService.todayDateString()

        guard lastFetchDate == today,
              let data = Self.sharedDefaults?.data(forKey: Self.mealsKey),
              let meals = try? JSONDecoder().decode([MealInfo].self, from: data) else {
            todayMeals = []
            return
        }
        todayMeals = meals
    }

    private func saveMeals(_ meals: [MealInfo], for date: String) {
        guard let data = try? JSONEncoder().encode(meals) else { return }
        Self.sharedDefaults?.set(data, forKey: Self.mealsKey)
        Self.sharedDefaults?.set(date, forKey: Self.mealsFetchDateKey)
        lastFetchDate = date
    }

    // MARK: - Fetching

    func fetchTodayMealsIfNeeded() async {
        let today = NEISService.todayDateString()
        if lastFetchDate == today && !todayMeals.isEmpty { return }
        await fetchMeals(for: today)
    }

    func refreshMeals() async {
        let today = NEISService.todayDateString()
        await fetchMeals(for: today)
    }

    private func fetchMeals(for date: String) async {
        guard isConfigured, let school = selectedSchool else {
            errorMessage = "학교 정보가 설정되지 않았습니다."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let meals = try await NEISService.fetchMeals(school: school, date: date, apiKey: apiKey)
            todayMeals = meals
            saveMeals(meals, for: date)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Static access for Widget

    nonisolated static func loadMealsFromDefaults() -> [MealInfo] {
        let today = NEISService.todayDateString()
        guard let defaults = sharedDefaults,
              defaults.string(forKey: mealsFetchDateKey) == today,
              let data = defaults.data(forKey: mealsKey),
              let meals = try? JSONDecoder().decode([MealInfo].self, from: data) else {
            return []
        }
        return meals
    }

    func mealsForFlag(_ flag: PeriodFlag) -> [MealInfo] {
        switch flag {
        case .lunch: todayMeals.filter { $0.mealCode == "2" }
        case .dinner: todayMeals.filter { $0.mealCode == "3" }
        default: []
        }
    }
}
