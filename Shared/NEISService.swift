import Foundation

enum NEISService {
    static let baseURL = "https://open.neis.go.kr/hub"

    enum NEISError: LocalizedError {
        case invalidURL
        case noData
        case apiError(String)
        case networkError(Error)

        var errorDescription: String? {
            switch self {
            case .invalidURL: "잘못된 URL입니다."
            case .noData: "데이터가 없습니다."
            case .apiError(let msg): msg
            case .networkError(let err): err.localizedDescription
            }
        }
    }

    static func searchSchools(query: String, apiKey: String) async throws -> [SchoolInfo] {
        guard var components = URLComponents(string: "\(baseURL)/schoolInfo") else {
            throw NEISError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "KEY", value: apiKey),
            URLQueryItem(name: "Type", value: "json"),
            URLQueryItem(name: "pIndex", value: "1"),
            URLQueryItem(name: "pSize", value: "20"),
            URLQueryItem(name: "SCHUL_NM", value: query),
        ]
        guard let url = components.url else { throw NEISError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        // Check for error
        if let result = json?["RESULT"] as? [String: Any],
           let code = result["CODE"] as? String, code != "INFO-000" {
            let message = result["MESSAGE"] as? String ?? "알 수 없는 오류"
            throw NEISError.apiError(message)
        }

        guard let schoolInfo = json?["schoolInfo"] as? [[String: Any]],
              schoolInfo.count > 1,
              let rows = schoolInfo[1]["row"] as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { row in
            guard let officeCode = row["ATPT_OFCDC_SC_CODE"] as? String,
                  let schoolCode = row["SD_SCHUL_CODE"] as? String,
                  let schoolName = row["SCHUL_NM"] as? String else { return nil }
            return SchoolInfo(
                officeCode: officeCode,
                schoolCode: schoolCode,
                schoolName: schoolName,
                schoolKind: row["SCHUL_KND_SC_NM"] as? String ?? "",
                address: row["ORG_RDNMA"] as? String ?? ""
            )
        }
    }

    static func fetchMeals(school: SchoolInfo, date: String, apiKey: String) async throws -> [MealInfo] {
        guard var components = URLComponents(string: "\(baseURL)/mealServiceDietInfo") else {
            throw NEISError.invalidURL
        }
        components.queryItems = [
            URLQueryItem(name: "KEY", value: apiKey),
            URLQueryItem(name: "Type", value: "json"),
            URLQueryItem(name: "ATPT_OFCDC_SC_CODE", value: school.officeCode),
            URLQueryItem(name: "SD_SCHUL_CODE", value: school.schoolCode),
            URLQueryItem(name: "MLSV_YMD", value: date),
        ]
        guard let url = components.url else { throw NEISError.invalidURL }

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let result = json?["RESULT"] as? [String: Any],
           let code = result["CODE"] as? String, code != "INFO-000" {
            // INFO-200 means no data for that date (not an error)
            if code == "INFO-200" { return [] }
            let message = result["MESSAGE"] as? String ?? "알 수 없는 오류"
            throw NEISError.apiError(message)
        }

        guard let mealInfo = json?["mealServiceDietInfo"] as? [[String: Any]],
              mealInfo.count > 1,
              let rows = mealInfo[1]["row"] as? [[String: Any]] else {
            return []
        }

        return rows.compactMap { row in
            guard let mealDate = row["MLSV_YMD"] as? String,
                  let mealCode = row["MMEAL_SC_CODE"] as? String,
                  let mealName = row["MMEAL_SC_NM"] as? String,
                  let dishStr = row["DDISH_NM"] as? String else { return nil }
            let dishes = dishStr
                .components(separatedBy: "<br/>")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .map { $0.replacingOccurrences(of: #"\s*\([0-9.]+\)"#, with: "", options: .regularExpression) }
                .filter { !$0.isEmpty }
            return MealInfo(
                date: mealDate,
                mealCode: mealCode,
                mealName: mealName,
                dishes: dishes,
                calorie: row["CAL_INFO"] as? String ?? ""
            )
        }
    }

    static func todayDateString(for date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }
}
