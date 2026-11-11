import SwiftUI

/// Экраны 01-03: «Отметьте трассы», «Сохраните комнату», «Сверлите без риска»
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let tag: String
        let title: String
        let text: String
        let photo: String
    }

    private let pages = [
        Page(tag: "До отделки", title: "Отметьте трассы\nдо отделки",
             text: "Соединяйте точки на открытой стене.\nКаждая труба и кабель - на своём месте.", photo: "wall_rough"),
        Page(tag: "Карта комнаты", title: "Сохраните\nкомнату",
             text: "Трассы, фото и заметки останутся\nв одной карте - не в галерее телефона.", photo: "wall_rough"),
        Page(tag: "После ремонта", title: "Сверлите\nбез риска",
             text: "Наведите камеру на готовую стену\nи проверьте место перед сверлением.", photo: "wall_finished"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ТРАССА").font(Theme.Fonts.inter(24, .bold)).foregroundStyle(Theme.Colors.accent)
                Spacer()
                Button("Пропустить", action: onFinish)
                    .font(Theme.Fonts.footnote)
                    .foregroundStyle(Theme.Colors.textSecondary)
                    .frame(height: 56)
            }
            .padding(.top, 4)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { i in
                    pageView(pages[i], index: i).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Индикатор страниц: активная - 22×6 оранжевая, остальные - 8×6
            HStack(spacing: 22) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Theme.Colors.accent : Theme.Colors.textMuted)
                        .frame(width: i == page ? 22 : 8, height: 6)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: page)
            .padding(.bottom, 37)

            Button(page == pages.count - 1 ? "Начать работу" : "Далее") {
                if page < pages.count - 1 { withAnimation { page += 1 } } else { onFinish() }
            }
            .buttonStyle(.primary)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .background(Theme.Colors.background.ignoresSafeArea())
    }

    private func pageView(_ p: Page, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            OnboardingIllustration(photo: p.photo, tag: p.tag, variant: index)
                .frame(height: 345)
                .padding(.top, 17)
            Text(String(format: "%02d / %02d", index + 1, pages.count))
                .font(Theme.Fonts.captionBold.weight(.bold))
                .foregroundStyle(Theme.Colors.accent)
                .padding(.top, 27)
            Text(p.title)
                .font(Theme.Fonts.largeTitle)
                .foregroundStyle(Theme.Colors.textPrimary)
                .lineSpacing(2)
                .padding(.top, 13)
            Text(p.text)
                .font(Theme.Fonts.body)
                .foregroundStyle(Theme.Colors.textSecondary)
                .padding(.top, 12)
            Spacer(minLength: 16)
        }
    }
}

/// Фото стены из макета с нарисованными поверх трассами
struct OnboardingIllustration: View {
    let photo: String
    let tag: String
    /// 0 - линии, 1 - карточка «сохранено», 2 - линии с красной зоной
    let variant: Int

    var body: some View {
        GeometryReader { geo in
            // Координаты линий взяты из макета (карточка 342×345) и масштабируются под ширину
            let s = geo.size.width / 342
            ZStack(alignment: .topLeading) {
                Image(photo).resizable().scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height).clipped()
                Theme.Colors.background.opacity(0.1)

                if variant != 1 {
                    let yellow = [CGPoint(x: 102, y: 289), CGPoint(x: 102, y: 124), CGPoint(x: 259, y: 124), CGPoint(x: 259, y: 67)]
                    let blue = [CGPoint(x: 46, y: 311), CGPoint(x: 46, y: 230), CGPoint(x: 206, y: 230)]
                    if variant == 2 {
                        polyline(yellow, s).stroke(Theme.Colors.danger.opacity(0.24),
                                                   style: StrokeStyle(lineWidth: 42 * s, lineCap: .round, lineJoin: .round))
                    }
                    polyline(blue, s).stroke(Theme.RouteColors.water, style: StrokeStyle(lineWidth: 5 * s, lineJoin: .round))
                    polyline(yellow, s).stroke(Theme.RouteColors.electric, style: StrokeStyle(lineWidth: 5 * s, lineJoin: .round))
                    ForEach(0..<3, id: \.self) { i in
                        Circle().fill(Theme.RouteColors.electric)
                            .frame(width: 10 * s, height: 10 * s)
                            .position(x: yellow[i].x * s, y: yellow[i].y * s)
                    }
                } else {
                    // Карточка подтверждения сохранения
                    VStack(alignment: .leading, spacing: 21) {
                        HStack(spacing: 16) {
                            Image(systemName: "checkmark").font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Theme.Colors.safe)
                            Text("Кухня сохранена").font(Theme.Fonts.inter(17, .semibold))
                                .foregroundStyle(Theme.Colors.textPrimary)
                        }
                        Text("4 трассы · привязка к стене").font(Theme.Fonts.footnoteRegular)
                            .foregroundStyle(Theme.Colors.textSecondary)
                    }
                    .padding(16)
                    .frame(width: 310 * s, height: 108, alignment: .leading)
                    .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: Theme.Metrics.radius))
                    .offset(x: 16 * s, y: 215 * s)
                }

                TagLabel(text: tag)
                    .frame(width: 155, alignment: .leading)
                    .background(Theme.Colors.background, in: RoundedRectangle(cornerRadius: 6))
                    .offset(x: 16, y: 17)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radius))
    }

    private func polyline(_ pts: [CGPoint], _ s: CGFloat) -> Path {
        Path { p in p.addLines(pts.map { CGPoint(x: $0.x * s, y: $0.y * s) }) }
    }
}
