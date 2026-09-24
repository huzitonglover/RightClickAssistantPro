import SwiftUI

private struct AssistantBuildMetadata {
    let appName: String
    let version: String
}

private struct AssistantAboutFact: Identifiable {
    let id: String
    let title: String
    let value: String
}

struct AssistantAboutSettingsView: View {
    private var metadata: AssistantBuildMetadata {
        AssistantBuildMetadata(
            appName: AssistantLocalized.appName,
            version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? AssistantLocalized.text(zh: "未知", en: "Unknown")
        )
    }

    private var facts: [AssistantAboutFact] {
        [
            .init(id: "name", title: AssistantLocalized.text(zh: "应用名称", en: "App Name"), value: metadata.appName),
            .init(id: "version", title: AssistantLocalized.text(zh: "当前版本", en: "Version"), value: metadata.version)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 24) {
                heroSection
                communityIdeaBanner
                factPanel
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 0)
            .padding(.bottom, 16)
        }
    }

    private var heroSection: some View {
        VStack(spacing: 16) {
            Image("AssistantBrandMark")
                .resizable()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
                }

            VStack(spacing: 8) {
                Text(metadata.appName)
                    .font(.title.weight(.semibold))
                Text("\(AssistantLocalized.text(zh: "版本", en: "Version")) \(metadata.version)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text(
                AssistantLocalized.text(
                    zh: "右键工具Pro聚焦 Finder 场景，把 Windows 常见右键操作整理成更顺手的 macOS 文件工作流。",
                    en: "RightMenuPro focuses on Finder workflows and brings familiar Windows-style context actions into a smoother macOS file experience."
                )
            )
                .font(.title3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 620)
        }
    }

    private var communityIdeaBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 6) {
                Text(AssistantLocalized.text(zh: "创意功能欢迎直接提", en: "Share Your Feature Ideas"))
                    .font(.headline)

                Text(
                    AssistantLocalized.text(
                        zh: "如果你有能明显提升效率的创意功能，欢迎直接在群里提出。我们会优先评估，并尽快安排更新落地。",
                        en: "If you have a feature idea that can clearly improve workflow efficiency, share it in the group. We review strong ideas first and ship practical updates as quickly as possible."
                    )
                )
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: 640, alignment: .leading)
        .background(Color.orange.opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.orange.opacity(0.24), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var factPanel: some View {
        GroupBox {
            VStack(spacing: 14) {
                ForEach(facts) { fact in
                    factRow(fact)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label(AssistantLocalized.text(zh: "应用信息", en: "App Info"), systemImage: "info.circle")
        }
        .frame(maxWidth: 640)
    }

    @ViewBuilder
    private func factRow(_ fact: AssistantAboutFact) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(fact.title)
                .foregroundStyle(.secondary)
                .frame(width: 88, alignment: .leading)
            Text(fact.value)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

#Preview {
    AssistantAboutSettingsView()
}
