import Foundation
import Testing
@testable import KiroUsage

struct KiroModelsTests {
    @Test func acceptsKiroExpirationWithMilliseconds() throws {
        let json = """
        {
          "accessToken": "test",
          "expiresAt": "2099-09-04T20:00:58.584Z",
          "provider": "Enterprise",
          "authMethod": "IdC",
          "region": "us-east-1"
        }
        """

        let credentials = try JSONDecoder().decode(KiroCredentials.self, from: Data(json.utf8))

        #expect(credentials.expirationDate != nil)
        #expect(credentials.isExpired == false)
    }

    @Test func parsesPrecisionValuesAndSelectsCredits() throws {
        let json = """
        {
          "nextDateReset": 1788220800,
          "subscriptionInfo": { "subscriptionTitle": "Kiro Pro" },
          "usageBreakdownList": [
            { "resourceType": "AGENTIC_REQUEST", "currentUsage": 8, "usageLimit": 50 },
            {
              "resourceType": "CREDIT",
              "displayNamePlural": "Credits",
              "currentUsage": 82,
              "currentUsageWithPrecision": 82.35,
              "usageLimit": 1000,
              "usageLimitWithPrecision": 1000
            }
          ]
        }
        """

        let response = try JSONDecoder().decode(KiroUsageResponse.self, from: Data(json.utf8))

        #expect(response.primaryBreakdown?.used == 82.35)
        #expect(response.primaryBreakdown?.limit == 1000)
        #expect(response.primaryBreakdown?.title == "Credits")
    }
}
