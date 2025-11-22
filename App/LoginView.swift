import SwiftUI

struct LoginView: View {
    @EnvironmentObject var session: SessionViewModel
    @State private var username: String = ""
    @State private var password: String = ""

    var body: some View {
        ZStack {
            Color(red: 239/255, green: 146/255, blue: 67/255)
                .ignoresSafeArea()
            VStack(spacing: 50) {
#if DEBUG
// In DEBUG builds a long-press on the logo will sign in as the demo root user
Image("main")
    .resizable()
    .scaledToFit()
    .frame(width: 250, height: 200)
    .onLongPressGesture(minimumDuration: 3.0) {
        Task { @MainActor in
            guard !session.isSigningIn else { return }
            _ = await session.signIn(username: "root", password: "changeMe")
        }
    }
#else
Image("main")
    .resizable()
    .scaledToFit()
    .frame(width: 250, height: 200)
#endif
                Text("PrepIt")
                    .font(.largeTitle.bold())
                

                VStack(spacing: 15) {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textContentType(.username)
                        .textFieldStyle(.roundedBorder)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(.roundedBorder)
                        .padding(8)
                        .background(Color.white)
                        .cornerRadius(8)
                    Button {
                        Task { @MainActor in
                            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
                            let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
                            _ = await session.signIn(username: trimmedUsername, password: trimmedPassword)
                        }
                    } label: {
                        if session.isSigningIn {
                            ProgressView()
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              session.isSigningIn)
                }

                if let errorMessage = session.signInError {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }

                
            }
            .padding()
        }
    }
}

