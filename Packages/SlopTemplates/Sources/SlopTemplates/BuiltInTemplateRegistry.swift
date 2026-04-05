import Foundation
import SlopKit

public struct BuiltInTemplateRegistry {
    /// The resource bundle for built-in template assets (skins, etc.).
    public static let resourceBundle: Bundle = Bundle.module

    nonisolated(unsafe) public static let all: [any AnySlopTemplate.Type] = [
        AppStoreScreenshotView_SlopTemplate.self,
        BudgetView_SlopTemplate.self,
        MarkdownEditorView_SlopTemplate.self,
        ColorPaletteView_SlopTemplate.self,
        CountdownView_SlopTemplate.self,
        DailyQuoteView_SlopTemplate.self,
        ExpenseTrackerView_SlopTemplate.self,
        FitnessLogView_SlopTemplate.self,
        GradeTrackerView_SlopTemplate.self,
        HabitTrackerView_SlopTemplate.self,
        InvoiceView_SlopTemplate.self,
        KanbanView_SlopTemplate.self,
        MealPlannerView_SlopTemplate.self,
        MoodLoggerView_SlopTemplate.self,
        PomodoroView_SlopTemplate.self,
        ReadingListView_SlopTemplate.self,
        RecipeView_SlopTemplate.self,
        ResumeView_SlopTemplate.self,
        SimpleNoteView_SlopTemplate.self,
        SlideView_SlopTemplate.self,
        StandupView_SlopTemplate.self,
        StickyNotesView_SlopTemplate.self,
        SubscriptionTrackerView_SlopTemplate.self,
        TodoListView_SlopTemplate.self,
        UnitConverterView_SlopTemplate.self,
        WaterIntakeView_SlopTemplate.self,
        WorldClockView_SlopTemplate.self,
        SpreadsheetView_SlopTemplate.self,
        FlashCardView_SlopTemplate.self,
        ClassScheduleView_SlopTemplate.self,
        StudyTimerView_SlopTemplate.self,
        LoanCalculatorView_SlopTemplate.self,
        NetWorthView_SlopTemplate.self,
        FIRECalculatorView_SlopTemplate.self,
        TripPlannerView_SlopTemplate.self,
        WeeklyPlannerView_SlopTemplate.self,
        PartyPlannerView_SlopTemplate.self,
        WorkoutPlannerView_SlopTemplate.self,
        MedicationScheduleView_SlopTemplate.self,
        HomeInventoryView_SlopTemplate.self,
        CleaningScheduleView_SlopTemplate.self,
        MeetingNotesView_SlopTemplate.self,
        ContactCRMView_SlopTemplate.self,
        // New templates from expansion plan
        InvestmentPortfolioView_SlopTemplate.self,
        DailyPlannerView_SlopTemplate.self,
        // TIER 2 Personal Life & Knowledge templates
        GoalTrackerView_SlopTemplate.self,
        GratitudeJournalView_SlopTemplate.self,
        BrainDumpView_SlopTemplate.self,
        DecisionJournalView_SlopTemplate.self,
        // TIER 1 Finance templates
        DebtPayoffPlannerView_SlopTemplate.self,
        SideHustleTrackerView_SlopTemplate.self,
        FinancialGoalsSimulatorView_SlopTemplate.self,
        TaxOptimizerView_SlopTemplate.self,
        // TIER 3 Work templates
        ProjectTrackerView_SlopTemplate.self,
        OKRTrackerView_SlopTemplate.self,
        // TIER 4 Health templates
        SymptomTrackerView_SlopTemplate.self,
        // TIER 5 Creative templates
        WritingTrackerView_SlopTemplate.self,
        // Clean-slate expansion templates
        WeeklyReviewView_SlopTemplate.self,
        PortfolioAllocatorView_SlopTemplate.self,
        SleepTrackerView_SlopTemplate.self,
        // AI Content templates
        AIGalleryView_SlopTemplate.self,
        SocialPostPreviewView_SlopTemplate.self,
        ContentReviewBoardView_SlopTemplate.self,
        PromptLabView_SlopTemplate.self,
        // Legal templates
        NDAView_SlopTemplate.self,
        ServiceAgreementView_SlopTemplate.self,
        ContractorAgreementView_SlopTemplate.self,
        LeaseAgreementView_SlopTemplate.self,
        EstateWillView_SlopTemplate.self,
        // Travel templates
        PackingListView_SlopTemplate.self,
        // Events templates
        WeddingPlannerView_SlopTemplate.self,
        // Media templates
        WatchListView_SlopTemplate.self,
        MediaReviewView_SlopTemplate.self,
        iMessageConversationView_SlopTemplate.self,
        iOSLockScreenView_SlopTemplate.self,
    ]

    /// Look up a built-in template by ID.
    public static func resolve(templateID: String) -> (any AnySlopTemplate.Type)? {
        all.first { $0.templateID == templateID }
    }

    /// Look up a built-in template by ID and version.
    public static func resolve(templateID: String, version: String) -> (any AnySlopTemplate.Type)? {
        all.first { $0.templateID == templateID && $0.version == version }
    }

    /// Build a manifest from a built-in template's static properties.
    public static func manifest(for type: any AnySlopTemplate.Type) -> TemplateManifest {
        TemplateManifest(
            id: type.templateID,
            name: type.name,
            description: type.templateDescription,
            version: type.version,
            minimumHostVersion: type.minimumHostVersion,
            bundleFile: nil,
            scriptFile: nil,
            previewFile: nil,
            metadata: type.metadata,
            schema: type.schema
        )
    }
}
