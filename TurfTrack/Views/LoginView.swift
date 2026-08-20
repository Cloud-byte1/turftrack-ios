import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var mode = "sign-in"
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(colors: [Theme.greenDeep, Theme.green], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("fairLie").font(.system(size: 32, weight: .heavy)).foregroundStyle(.white)
                        Text("Train your strike. Own your game.").foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(20)
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 8) {
                        chip("Sign in", id: "sign-in")
                        chip("Create account", id: "sign-up")
                    }
                    .padding(4)
                    .background(Color(white: 0.94), in: RoundedRectangle(cornerRadius: 12))

                    Text(mode == "sign-in" ? "Welcome back" : "Join the fairway")
                        .font(.title3.weight(.bold))
                    Text(mode == "sign-in"
                         ? "Sign in to sync sessions, stats, and clubhouse."
                         : "Create your profile and start tracking strike data.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.muted)

                    if mode == "sign-up" {
                        field("Name", text: $name, hint: "Your name")
                    }
                    field("Email", text: $email, hint: "you@email.com")
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    SecureField("At least 6 characters", text: $password)
                        .padding(12)
                        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topLeading) {
                            Text("Password").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                                .offset(y: -18)
                        }
                        .padding(.top, 12)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Theme.danger)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.danger.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Button(mode == "sign-in" ? "Sign in" : "Create account") {
                        if mode == "sign-in" {
                            auth.signIn(email: email, password: password)
                        } else {
                            auth.signUp(name: name, email: email, password: password)
                        }
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Theme.green, in: Capsule())

                    Text("Accounts are saved on this device for the demo. Connect a mat after signing in.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }
                .padding(18)
                .fairCard()
            }
            .padding(18)
        }
        .background(Theme.cream.ignoresSafeArea())
    }

    private func chip(_ title: String, id: String) -> some View {
        Button(title) { mode = id; auth.errorMessage = nil }
            .font(.caption.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(mode == id ? Color.white : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .foregroundStyle(mode == id ? Theme.green : Theme.muted)
    }

    private func field(_ label: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
            TextField(hint, text: text)
                .padding(12)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct ProfileSetupView: View {
    @EnvironmentObject private var auth: AuthStore
    @State private var city = "Miami, FL"
    @State private var handicap = 18.0
    @State private var skill = "Beginner"
    @State private var bag: Set<String> = ["Driver", "7 Iron", "Pitching Wedge"]

    private let skills = ["Beginner", "Range Regular", "Ball Striker", "Shot Shaper"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("PROFILE SETUP").eyebrowStyle()
                Text("Build your golfer card").font(.system(size: 28, weight: .bold))
                Text("This unlocks Clubhouse, challenges, and your public profile.")
                    .foregroundStyle(Theme.muted)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Home course / city").font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                    TextField("City", text: $city)
                        .padding(12)
                        .background(Theme.cream, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(16)
                .fairCard()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Handicap").font(.subheadline.weight(.bold))
                        Spacer()
                        Text(String(format: "%.1f", handicap)).font(.headline).foregroundStyle(Theme.greenDark)
                    }
                    Slider(value: $handicap, in: 0...36, step: 0.1).tint(Theme.green)
                }
                .padding(16)
                .fairCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Skill level").font(.subheadline.weight(.bold))
                    ForEach(skills, id: \.self) { item in
                        Button {
                            skill = item
                        } label: {
                            HStack {
                                Text(item)
                                Spacer()
                                if skill == item { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green) }
                            }
                            .padding(12)
                            .background(skill == item ? Color(red: 0.91, green: 0.96, blue: 0.93) : Theme.cream, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .foregroundStyle(Theme.ink)
                    }
                }
                .padding(16)
                .fairCard()

                VStack(alignment: .leading, spacing: 10) {
                    Text("My bag").font(.subheadline.weight(.bold))
                    FlexibleBag(selected: $bag)
                }
                .padding(16)
                .fairCard()

                Button("Enter the clubhouse") {
                    auth.completeSetup(city: city, handicap: handicap, skill: skill, bag: Array(bag))
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.green, in: Capsule())
            }
            .padding(18)
        }
        .background(Theme.cream.ignoresSafeArea())
        .onAppear {
            city = auth.session?.city.isEmpty == false ? auth.session!.city : city
        }
    }
}

struct FlexibleBag: View {
    @Binding var selected: Set<String>

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            ForEach(FairLieCatalog.clubs, id: \.self) { club in
                Button {
                    if selected.contains(club) { selected.remove(club) } else { selected.insert(club) }
                } label: {
                    Text(club)
                        .font(.caption.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(selected.contains(club) ? Theme.green : Theme.cream, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(selected.contains(club) ? .white : Theme.ink)
                }
            }
        }
    }
}
