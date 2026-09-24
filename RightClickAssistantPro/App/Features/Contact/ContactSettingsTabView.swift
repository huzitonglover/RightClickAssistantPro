import SwiftUI

struct ContactSettingsTabView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                headerSection
                communityIdeaBanner
                contactSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(AssistantLocalized.text(zh: "联系我们", en: "Contact Us"))
                .font(.system(size: 34, weight: .semibold))

            Text(
                AssistantLocalized.text(
                    zh: "功能建议、使用问题、合作沟通，都可以直接通过 QQ 群联系。",
                    en: "For feature ideas, support issues, or collaboration, you can reach out directly through the QQ group."
                )
            )
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var communityIdeaBanner: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bolt.badge.clock.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(red: 0.24, green: 0.61, blue: 0.96))

            VStack(alignment: .leading, spacing: 6) {
                Text(AssistantLocalized.text(zh: "创意功能可以直接在群里提", en: "Feature Ideas Welcome"))
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
        .frame(maxWidth: 720, alignment: .leading)
        .background(Color(red: 0.24, green: 0.61, blue: 0.96).opacity(0.10))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(red: 0.24, green: 0.61, blue: 0.96).opacity(0.24), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var contactSection: some View {
        contactPanel(
            title: AssistantLocalized.text(zh: "QQ 交流群", en: "QQ Group"),
            description: AssistantLocalized.text(
                zh: "适合提交问题反馈、查看新功能动态，也方便和其他用户交流使用场景。",
                en: "Best for issue reports, feature updates, and discussing use cases with other users."
            ),
            highlight: AssistantLocalized.text(zh: "群号 1080620237", en: "Group ID 1080620237"),
            accentColor: Color(red: 0.24, green: 0.61, blue: 0.96)
        )
    }

    @ViewBuilder
    private func contactPanel(
        title: String,
        description: String,
        highlight: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(accentColor)
                    Text(title)
                        .font(.system(size: 24, weight: .semibold))
                }

                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(highlight)
                .font(.headline)
                .foregroundStyle(accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(accentColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .textSelection(.enabled)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    ContactSettingsTabView()
}
