//
// BitcoinWidget.swift
// BitcoinLive
// Copyright (c) 2022 and All rights reserved.
//

import WidgetKit
import SwiftUI
import Charts

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Bitcoin {
        Bitcoin(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (Bitcoin) -> ()) {
        let entry = Bitcoin(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        
        let currentDate = Date()
        Task{
            if var bitcoinData = try? await fetchData(){
                bitcoinData.date = currentDate
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
                let timeline = Timeline(entries: [bitcoinData], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
    
    func fetchData()async throws -> Bitcoin{
        let session = URLSession(configuration: .default)
        let response = try await session.data(from: URL(string: APIURL)!)
        let bitcoinData = try JSONDecoder().decode([Bitcoin].self, from: response.0)
        if let bitcoin = bitcoinData.first{
            return bitcoin
        }
        return .init()
    }
}


//API

fileprivate let APIURL =
"https://api.coingecko.com/api/v3/coins/markets?vs_currency=usd&ids=bitcoin&order=market_cap_desc&per_page=1008page=1&sparkline=true&price_change_percentage=7d"

struct Bitcoin: TimelineEntry, Codable {
    var date: Date = .init()
    var priceChange: Double = 0.0
    var currentPrice: Double = 0.0
    var last7Days: SparklineData = .init()
    
    enum CodingKeys: String, CodingKey {
        case priceChange = "price_change_percentage_7d_in_currency"
        case currentPrice = "current_price"
        case last7Days = "sparkline_in_7d"
        
    }
}

struct SparklineData: Codable{
    var price: [Double] = []
    
    enum CodingKeys: String, CodingKey {
        case price = "price"
    }
    
}

struct BitcoinWidgetEntryView : View {
    var Bitcoin: Provider.Entry

    @Environment(\.widgetFamily) var family
    
    
    var body: some View {
        //Text("\(Bitcoin.last7Days.price.count)")
        
        if family == .systemMedium {
            MediumSizedWidget()
        }else{
            LockScreenWidget()
        }
    }
    
    @ViewBuilder
    func LockScreenWidget()->some View{
        VStack(alignment: .leading){
            HStack{
                Image("Bitcoin Bordered")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                
                VStack(alignment: .leading){
                    Text("Bitcoin")
                        .font(.callout)
                    Text("BTC")
                        .font(.caption2)
                }
            }
            HStack{
                Text(Bitcoin.currentPrice.toCurrency())
                    .font(.callout)
                    .fontWeight(.semibold)
                Text(Bitcoin.priceChange.toString(floatingPoint: 1) + "%")
                    .font(.caption2)
            }
        }
    }
    
    
    @ViewBuilder
    func MediumSizedWidget()->some View{
        ZStack {
            Rectangle()
                .fill(Color("WidgetBackground"))
                /*.fill(Color(red: 0.82, green: 0.21, blue: 0.85).opacity(4.7))*/
            
            VStack{
                HStack{
                    Image("Bitcoin")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                    
                    VStack(alignment: .leading){
                        Text("Bitcoin")
                            .foregroundColor(.white)
                        Text("BTC")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(Bitcoin.currentPrice.toCurrency())")
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                HStack(spacing: 15){
                    VStack(spacing: 8){
                        Text("Bu hafta")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(Bitcoin.priceChange.toString(floatingPoint: 1)+"%")
                            .fontWeight(.semibold)
                            .foregroundColor(Bitcoin.priceChange < 0 ? .red : Color("Green"))
                    }
                    
                    Chart {
                        let graphColor = Bitcoin.priceChange < 0 ? Color.red : Color("Green")
                        ForEach(Bitcoin.last7Days.price.indices, id: \.self){ index in
                            LineMark(x: .value("Hour", index), y: .value("Price", Bitcoin.last7Days.price[index] - min()))
                                .foregroundStyle(graphColor)
                            
                            //
                            
                            AreaMark(x: .value("Hour", index), y: .value("Price", Bitcoin.last7Days.price[index] - min()))
                                .foregroundStyle(.linearGradient(colors: [graphColor.opacity(0.2), graphColor.opacity(0.1),.clear], startPoint: .top, endPoint: .bottom))
                            
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                }
            }
            .padding(.all)
        }
    }
    
    func min()->Double{
        if let min = Bitcoin.last7Days.price.min(){
            return min
        }
        return 0.0
    }
}

struct BitcoinWidget: Widget {
    let kind: String = "BitcoinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            BitcoinWidgetEntryView(Bitcoin: entry)
        }
        .supportedFamilies([.systemMedium, .accessoryRectangular])
        .configurationDisplayName("My Widget")
        .description("This is an example widget.")
    }
}

struct BitcoinWidget_Previews: PreviewProvider {
    static var previews: some View {
        BitcoinWidgetEntryView(Bitcoin: Bitcoin(date: Date()))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}

extension Double{
    func toCurrency()->String{
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        
        return formatter.string(from: .init(value: self)) ?? "$0.00"
    }
    
    func toString(floatingPoint: Int)->String {
        let string = String(format: "%.\(floatingPoint)f", self)
        return string
    }
}

