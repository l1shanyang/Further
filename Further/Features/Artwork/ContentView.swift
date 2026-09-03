import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Spacer()

            Text(AppText.productName)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .tracking(-1.5)
                .accessibilityIdentifier("launch.product-name")

            Text(AppText.launchTagline)
                .font(.callout)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("launch.tagline")

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(32)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        AppComposition.testing().rootView
    }
}
