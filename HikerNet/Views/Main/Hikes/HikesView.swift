
import SwiftUI

struct HikesView: View {
    @State private var hikes = [HikeResponse]()
    @State private var totalDistance: Double = 0.0
    @State private var totalTime: String = "00:00:00"
    @State private var downloading: Bool = false
    @State private var errorTitle: String = ""
    @State private var errorMessage: String = ""
    
    var body: some View {
        NavigationView {
            if downloading {
                LottieView(name: "loading", play: $downloading, loop: true)
                    .frame(width: UIScreen.main.bounds.width, height: 200)
            } else {
                if hikes.count > 0 {
                    ScrollView(showsIndicators: true) {
                        VStack(alignment: .leading) {
                            Text("Your Hikes")
                                .foregroundColor(.primary)
                                .font(Font.custom(Constants.Fonts.medium, size: 28))
                            
                            HikeConnectivityView(hikes: hikes)
                                .padding(EdgeInsets(top: 8, leading: 0, bottom: 24, trailing: 0))
                            
                            HStack {
                                HStack(alignment: .center, spacing: 32) {
                                    VStack(alignment: .leading) {
                                        Text("\(hikes.count)")
                                            .foregroundColor(.primary)
                                            .font(Font.custom(Constants.Fonts.medium, size: 21))
                                        Text("hikes")
                                            .foregroundColor(.secondary)
                                            .font(Font.custom(Constants.Fonts.regular, size: 14))
                                    }
                                    VStack(alignment: .leading) {
                                        Text(String(format: "%.2f", arguments: [totalDistance]) + " km")
                                            .foregroundColor(.primary)
                                            .font(Font.custom(Constants.Fonts.medium, size: 21))
                                        Text("distance")
                                            .foregroundColor(.secondary)
                                            .font(Font.custom(Constants.Fonts.regular, size: 14))
                                    }
                                    VStack(alignment: .leading) {
                                        Text(totalTime)
                                            .foregroundColor(.primary)
                                            .font(Font.custom(Constants.Fonts.medium, size: 21))
                                        Text("time")
                                            .foregroundColor(.secondary)
                                            .font(Font.custom(Constants.Fonts.regular, size: 14))
                                    }
                                }
                                Spacer()
                            }
                            .padding(EdgeInsets(top: 24, leading: 0, bottom: 0, trailing: 0))
                            
                            VStack(alignment: .leading) {
                                Text("Recent Activity")
                                    .foregroundColor(.primary)
                                    .font(Font.custom(Constants.Fonts.medium, size: 28))
                                ForEach(hikes) { hike in
                                    NavigationLink(destination: HikeDetailView(hike: hike)) {
                                        HikeItemView(hike: hike)
                                            .padding(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
                                    }
                                }
                            }
                            .padding(EdgeInsets(top: 24, leading: 0, bottom: 0, trailing: 0))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                        .padding(EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24))
                        .ignoresSafeArea(.all, edges: .top)
                    }
                    .navigationBarHidden(true)
                    .navigationBarBackButtonHidden(true)
                } else {
                    VStack(alignment: .center, spacing: 16) {
                        LottieView(name: "smores", play: .constant(true), loop: true)
                            .frame(width: UIScreen.main.bounds.width, height: 200)
                        Text(errorTitle)
                            .foregroundColor(.primary)
                            .font(Font.custom(Constants.Fonts.medium, size: 28))
                            .padding(EdgeInsets(top: 16, leading: 36, bottom: 0, trailing: 36))
                        Text(errorMessage)
                            .foregroundColor(.secondary)
                            .font(Font.custom(Constants.Fonts.regular, size: 21))
                            .multilineTextAlignment(.center)
                            .padding(EdgeInsets(top: 0, leading: 36, bottom: 0, trailing: 36))
                    }
                    .navigationBarHidden(true)
                    .navigationBarBackButtonHidden(true)
                }
            }
                
        }
        .statusBar(hidden: true)
        .background(Color(UIColor.systemBackground))
        .onAppear() {
            downloading = true
            ApiManager.postHikes { res in
                switch res {
                case .success(.Success):
                    DatabaseManager.clearCache()
                case .failure(let err):
                    print(err.localizedDescription)
                }
                ApiManager.getHikes { res in
                    switch res {
                    case .success(let data):
                        if data.count < 1 {
                            errorTitle = "No Hikes"
                            errorMessage = "You haven't recorded any hikes. Start recording to see your data!"
                        }
                        hikes = data
                        calcTotalDistance()
                        calcTotalTime()
                    case .failure(let err):
                        switch err {
                        case .RequestError:
                            errorTitle = "Request Error"
                            errorMessage = "We had a problem getting your hikes. Please try again later."
                        case .ServerError:
                            errorTitle = "Server Error"
                            errorMessage = "Our servers are having some issues. Please try again later."
                        case .ConnectionError:
                            errorTitle = "Connection Error"
                            errorMessage = "There was a problem with the connection. Make sure you're connected to the internet."
                            
                        }
                    }
                    downloading = false
                }
            }
        }
    }
    
    private func calcTotalDistance() {
        totalDistance = 0
        for hike in hikes {
            totalDistance += hike.distance
        }
    }
    
    private func calcTotalTime() {
        var total = 0
        for hike in hikes {
            total += hike.duration
        }
        totalTime = TimeFormatter.getStopWatchTime(elapsedSeconds: total)
    }

}

struct HikesView_Previews: PreviewProvider {
    static var previews: some View {
        HikesView()
    }
}