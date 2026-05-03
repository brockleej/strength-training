//
//  ConfigArtifactRoundTripTests.swift
//  progression-lab-tests
//

import XCTest
@testable import ProgressionLab

final class ConfigArtifactRoundTripTests: XCTestCase {

    private func emptyDataset() -> LoadedDataset {
        LoadedDataset(
            sourceURL: URL(fileURLWithPath: "/tmp/test.json"),
            exportedAt: Date(),
            exercises: [],
            summary: LoadedDatasetSummary(
                exerciseCount: 0,
                sessionCount: 0,
                dateRangeStart: nil,
                dateRangeEnd: nil,
                skipReasons: [:]
            )
        )
    }

    func test_roundTripPreservesParameters() throws {
        var experiment = ProgressionParameters.productionModerate
        experiment.consistencyThreshold = 1
        experiment.strengthRepCap = 25
        experiment.weightIncrement = 2.5

        let artifact = ConfigArtifactWriter.build(
            name: "test-experiment",
            description: "for unit test",
            parameters: experiment,
            baseline: .productionModerate,
            baselineName: "productionModerate",
            dataset: emptyDataset(),
            replays: []
        )

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("artifact-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: tmpURL) }

        try ConfigArtifactWriter.write(artifact, to: tmpURL)

        let (loaded, name) = try ConfigArtifactReader.load(from: tmpURL)
        XCTAssertEqual(loaded, experiment)
        XCTAssertEqual(name, "test-experiment")
    }

    func test_diffFromProductionOnlyIncludesChangedFields() {
        var experiment = ProgressionParameters.productionModerate
        experiment.consistencyThreshold = 3
        experiment.strengthRepCap = 25

        let artifact = ConfigArtifactWriter.build(
            name: "diff-test",
            description: "",
            parameters: experiment,
            baseline: .productionModerate,
            baselineName: "productionModerate",
            dataset: emptyDataset(),
            replays: []
        )

        XCTAssertEqual(artifact.diffFromProduction.count, 2)
        XCTAssertNotNil(artifact.diffFromProduction["consistencyThreshold"])
        XCTAssertNotNil(artifact.diffFromProduction["strengthRepCap"])
        XCTAssertNil(artifact.diffFromProduction["averageWindow"])
        XCTAssertNil(artifact.diffFromProduction["weightIncrement"])
    }

    func test_emptyDatasetGivesZeroComparisonStats() {
        let artifact = ConfigArtifactWriter.build(
            name: "stats-test",
            description: "",
            parameters: .productionModerate,
            baseline: .productionModerate,
            baselineName: "productionModerate",
            dataset: emptyDataset(),
            replays: []
        )
        XCTAssertEqual(artifact.comparisonStats.vsProduction.totalDecisions, 0)
        XCTAssertEqual(artifact.comparisonStats.vsProduction.agreementRate, 0)
        XCTAssertEqual(artifact.comparisonStats.vsProduction.weightBumpsExperiment, 0)
    }

    func test_suggestedFilenameSlugsName() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let date = formatter.date(from: "2026-05-03")!
        let filename = ConfigArtifactWriter.suggestedFilename(name: "Aggressive Shoulders!", createdAt: date)
        XCTAssertEqual(filename, "2026-05-03-aggressive-shoulders.json")
    }

    func test_unsupportedSchemaVersionThrows() throws {
        let jsonString = """
        {
          "schemaVersion": 999,
          "name": "test",
          "description": "",
          "createdAt": "2026-05-03T12:00:00Z",
          "basedOnDataset": { "filename": "f.json", "exerciseCount": 0, "sessionCount": 0, "dateRange": null },
          "baseline": "productionModerate",
          "parameters": { "averageWindow": 4, "consistencyThreshold": 2, "strengthRepCap": 20, "enduranceCeilingOffset": 20, "weightIncrement": 5, "repIncrement": 1 },
          "diffFromProduction": {},
          "comparisonStats": { "vsProduction": { "agreementRate": 0, "weightBumpsExperiment": 0, "weightBumpsProduction": 0, "totalDecisions": 0 } }
        }
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("v999-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try jsonString.data(using: .utf8)!.write(to: url)

        XCTAssertThrowsError(try ConfigArtifactReader.load(from: url)) { error in
            guard case ConfigArtifactReaderError.unsupportedSchemaVersion(let found, let supported) = error else {
                XCTFail("Wrong error: \(error)")
                return
            }
            XCTAssertEqual(found, 999)
            XCTAssertEqual(supported, 1)
        }
    }
}
