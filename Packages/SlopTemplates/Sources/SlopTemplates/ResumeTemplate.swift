import Foundation
import SwiftUI
import SlopKit

@SlopData
public struct ResumeSkill: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Skill") var name: String = ""
}

@SlopData
public struct ResumeExperience: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("Role") var title: String = ""
    @Field("Company") var company: String = ""
    @Field("Timeframe") var timeframe: String = ""
    @Field("Summary") var summary: String = ""
}

@SlopData
public struct ResumeEducation: Identifiable {
    @Field("ID") public var id: String = UUID().uuidString
    @Field("School") var school: String = ""
    @Field("Degree") var degree: String = ""
    @Field("Year") var year: String = ""
}

@SlopData
public struct ResumeData {
    @SlopKit.Section("Profile") @Field("Full Name") var fullName: String = "Alex Chen"
    @Field("Headline") var headline: String = "Senior Software Engineer"
    @Field("Summary") var summary: String = "Builder of fast, local-first product systems with a bias for shipping polished tooling."
    @Field("Email") var email: String = "alex@example.com"
    @Field("Location") var location: String = "San Francisco, CA"
    @Field("Website") var website: String = "github.com/alex"

    @SlopKit.Section("Skills") @Field("Skills") var skills: [ResumeSkill] = ResumeData.defaultSkills
    @SlopKit.Section("Experience") @Field("Experience") var experience: [ResumeExperience] = ResumeData.defaultExperience
    @SlopKit.Section("Education") @Field("Education") var education: [ResumeEducation] = ResumeData.defaultEducation
}

extension ResumeData {
    static var defaultSkills: [ResumeSkill] {
        func skill(_ name: String) -> ResumeSkill {
            var value = ResumeSkill()
            value.name = name
            return value
        }

        return ["Swift", "SwiftUI", "Rust", "TypeScript", "React", "Local-first"].map(skill)
    }

    static var defaultExperience: [ResumeExperience] {
        func job(_ title: String, _ company: String, _ timeframe: String, _ summary: String) -> ResumeExperience {
            var value = ResumeExperience()
            value.title = title
            value.company = company
            value.timeframe = timeframe
            value.summary = summary
            return value
        }

        return [
            job("Lead Engineer", "Acme Inc.", "2022 - Present", "Led a small product engineering team shipping a real-time collaboration stack with measurable latency wins."),
            job("Software Engineer", "StartupCo", "2020 - 2022", "Built the iOS app from scratch and designed an offline sync layer that scaled to tens of thousands of monthly users."),
            job("Junior Developer", "BigTech", "2018 - 2020", "Automated release and deployment workflows, cutting a painful multi-hour process down to minutes."),
        ]
    }

    static var defaultEducation: [ResumeEducation] {
        var entry = ResumeEducation()
        entry.school = "Stanford University"
        entry.degree = "B.S. Computer Science"
        entry.year = "2018"
        return [entry]
    }
}

// MARK: - Template

@SlopTemplate(
    id: "com.hitslop.templates.resume",
    name: "Resume",
    description: "Edit a modern one-page resume with experience, skills, and education.",
    version: "1.0.0",
    width: 500, height: 640,
    minWidth: 420, minHeight: 520,
    shape: .roundedRect(radius: 18),
    theme: "mono",
    alwaysOnTop: true,
    categories: ["business"]
)
struct ResumeView: View {
    @TemplateData var data: ResumeData
    @Environment(\.slopTheme) private var theme
    @Environment(\.slopRenderTarget) private var renderTarget

    var body: some View {
        Group {
            if renderTarget == .interactive {
                ScrollView(showsIndicators: false) { interactiveContent }
            } else {
                exportContent
            }
        }
        .background(theme.background)
    }

    private var interactiveContent: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("Contact")
                SlopTextField("Email", text: $data.email)
                    .font(theme.font(size: 12))
                    .foregroundStyle(theme.foreground)
                SlopTextField("Location", text: $data.location)
                    .font(theme.font(size: 12))
                    .foregroundStyle(theme.foreground)
                SlopTextField("Website", text: $data.website)
                    .font(theme.font(size: 12))
                    .foregroundStyle(theme.foreground)

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Skills")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach($data.skills) { $skill in
                            HStack(spacing: 2) {
                                SlopTextField("Skill", text: $skill.name)
                                    .font(theme.font(size: 11, weight: .semibold))
                                    .foregroundStyle(theme.background)
                                SlopInteractiveOnly {
                                    Button {
                                        withAnimation { data.skills.removeAll { $0.id == skill.id } }
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(theme.font(size: 8, weight: .bold))
                                            .foregroundStyle(theme.background.opacity(0.6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(theme.accent))
                        }
                    }
                    SlopInteractiveOnly {
                        Button {
                            withAnimation { data.skills.append(ResumeSkill()) }
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.caption)
                                .foregroundStyle(theme.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Education")
                    ForEach($data.education) { $item in
                        VStack(alignment: .leading, spacing: 4) {
                            SlopTextField("School", text: $item.school)
                                .font(theme.font(size: 13, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            SlopTextField("Degree", text: $item.degree)
                                .foregroundStyle(theme.secondary)
                            HStack {
                                SlopTextField("Year", text: $item.year)
                                    .foregroundStyle(theme.secondary.opacity(0.7))
                                SlopInteractiveOnly {
                                    Button {
                                        withAnimation { data.education.removeAll { $0.id == item.id } }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(theme.font(size: 10))
                                            .foregroundStyle(theme.secondary.opacity(0.3))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    SlopInteractiveOnly {
                        Button {
                            withAnimation { data.education.append(ResumeEducation()) }
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.caption)
                                .foregroundStyle(theme.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(width: 150, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    SlopTextField("Full Name", text: $data.fullName)
                        .font(theme.title(size: 30))
                        .foregroundStyle(theme.foreground)
                    SlopTextField("Headline", text: $data.headline)
                        .font(theme.font(size: 15, weight: .medium))
                        .foregroundStyle(theme.accent)
                    SlopEditable($data.summary) { value in
                        Text(value)
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } editor: { binding in
                        TextEditor(text: binding)
                            .foregroundStyle(theme.secondary)
                            .scrollContentBackground(.hidden)
                            .font(theme.font(size: 13))
                            .frame(minHeight: 40)
                    }
                }

                Divider().background(theme.divider)

                HStack {
                    sectionTitle("Experience")
                    Spacer()
                    SlopInteractiveOnly {
                        Button {
                            withAnimation { data.experience.append(ResumeExperience()) }
                        } label: {
                            Label("Add", systemImage: "plus")
                                .font(.caption)
                                .foregroundStyle(theme.secondary.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }

                ForEach($data.experience) { $job in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            HStack(spacing: 4) {
                                SlopTextField("Role", text: $job.title)
                                    .font(theme.font(size: 14, weight: .semibold))
                                    .foregroundStyle(theme.foreground)
                                Text("\u{2014}")
                                    .foregroundStyle(theme.foreground)
                                SlopTextField("Company", text: $job.company)
                                    .font(theme.font(size: 14, weight: .semibold))
                                    .foregroundStyle(theme.foreground)
                            }
                            Spacer()
                            SlopTextField("Period", text: $job.timeframe)
                                .font(theme.mono(size: 11, weight: .medium))
                                .foregroundStyle(theme.secondary)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 100)
                        }
                        SlopTextField("Summary", text: $job.summary)
                            .foregroundStyle(theme.secondary)
                        SlopInteractiveOnly {
                            HStack {
                                Spacer()
                                Button {
                                    withAnimation { data.experience.removeAll { $0.id == job.id } }
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(theme.font(size: 10))
                                        .foregroundStyle(theme.secondary.opacity(0.3))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.divider.opacity(0.45))
                            .frame(height: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(26)
    }

    private var exportContent: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("Contact")
                sideText(data.email)
                sideText(data.location)
                sideText(data.website)

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Skills")
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], alignment: .leading, spacing: 8) {
                        ForEach(data.skills) { skill in
                            Text(skill.name)
                                .font(theme.font(size: 11, weight: .semibold))
                                .foregroundStyle(theme.background)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(theme.accent))
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    sectionTitle("Education")
                    ForEach(data.education) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.school)
                                .font(theme.font(size: 13, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            Text(item.degree)
                                .foregroundStyle(theme.secondary)
                            Text(item.year)
                                .foregroundStyle(theme.secondary.opacity(0.7))
                        }
                    }
                }
            }
            .frame(width: 150, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.fullName)
                        .font(theme.title(size: 30))
                        .foregroundStyle(theme.foreground)
                    Text(data.headline)
                        .font(theme.font(size: 15, weight: .medium))
                        .foregroundStyle(theme.accent)
                    Text(data.summary)
                        .foregroundStyle(theme.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().background(theme.divider)

                sectionTitle("Experience")

                ForEach(data.experience) { job in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("\(job.title) \u{2014} \(job.company)")
                                .font(theme.font(size: 14, weight: .semibold))
                                .foregroundStyle(theme.foreground)
                            Spacer()
                            Text(job.timeframe)
                                .font(theme.mono(size: 11, weight: .medium))
                                .foregroundStyle(theme.secondary)
                        }
                        Text(job.summary)
                            .foregroundStyle(theme.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.bottom, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(theme.divider.opacity(0.45))
                            .frame(height: 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(26)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased())
            .font(theme.mono(size: 10, weight: .bold))
            .foregroundStyle(theme.secondary)
    }

    private func sideText(_ value: String) -> some View {
        Text(value)
            .font(theme.font(size: 12))
            .foregroundStyle(theme.foreground)
    }
}

