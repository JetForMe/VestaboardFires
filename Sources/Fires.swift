import ArgumentParser
import Foundation






struct
Fire : Codable
{
	let	name			:	String
	let	updated			:	Date
	let	started			:	Date
	let	acresBurned		:	Double
	let	containment		:	Double
	
	enum
	CodingKeys : String, CodingKey
	{
		case name			=	"Name"
		case started		=	"Started"
		case updated		=	"Updated"
		case acresBurned	=	"AcresBurned"
		case containment	=	"PercentContained"
	}
	
	init(from inDecoder: any Decoder)
		throws
	{
		let container = try inDecoder.container(keyedBy: CodingKeys.self)
		self.name = try container.decode(String.self, forKey: .name)
		let df = DateFormatter()
		df.dateFormat = "yyyy-MM-dd"
//		self.updated = df.date(from: try container.decode(String.self, forKey: .updated))!
		self.updated = Self.decodeDumbDate(try container.decode(String.self, forKey: .updated))
		self.started = Self.decodeDumbDate(try container.decode(String.self, forKey: .started))
		self.acresBurned = try container.decode(Double.self, forKey: .acresBurned)
		self.containment = try container.decode(Double.self, forKey: .containment)
	}
	
	/**
		The date values take the form "\Date(<milliseconds>)".
	*/
	
	static
	func
	decodeDumbDate(_ inS: String)
		-> Date
	{
		let msS = inS.filter { $0.isNumber }
		let ms = Double(msS)! + 8 * 3600 * 1000				//	Add eight hours because the time stamp is in PST, not UTC (urghh)
		return Date(timeIntervalSince1970: ms / 1000.0)
	}
}






@main
struct
Fires : AsyncParsableCommand
{
	mutating
	func
	run()
		async
		throws
	{
		print("Vestaboard Fire Updater")
		
		repeat
		{
			print("Updating board")
			await updateBoard()
			try? await Task.sleep(for: .seconds(5 * 60.0))
			
		} while (!Task.isCancelled)
	}
	
	mutating
	func
	updateBoard()
		async
	{
		do
		{
			let paths = try await fetchPaths().prefix(4)
			print("Got \(paths.count) fires")
			
			let fires = try await withThrowingTaskGroup(of: (String, Fire?).self)
			{ group in
				for path in paths
				{
					group.addTask
					{
						return (path, try? await Self.fetchFireDetail(for: path))
					}
				}
				
				//	Gather the results from the tasks above into a dictionary by URL…
				
				let dict = try await group.reduce(into: [:]) { $0[$1.0] = $1.1 }
				
				//	Order them by original order…
				
				let results = paths.compactMap { dict[$0] }
				return results
			}
			
			let codes = try await format(fires: fires)
			try await sendMessage(codes: codes)
		}
		
		catch
		{
			print("Error updating board: \(error.localizedDescription)")
		}
	}
	
	func
	fetchPaths()
		async
		throws
		-> [String]
	{
		struct
		FireURL : Codable
		{
			let	urlPath			:	String
			enum
			CodingKeys : String, CodingKey
			{
				case urlPath		=	"Url"
			}
		}
		
		let endpoint = URL(string: "https://www.fire.ca.gov/api/sitecore/Incident/GetFiresForMap")!
		let req = URLRequest(url: endpoint)
		let (data, _) = try await URLSession.shared.data(for: req)
//		print("resp: \(String(data: data, encoding: .utf8) ?? "")")
		let fires = try JSONDecoder().decode([FireURL].self, from: data)
//		print("Fires: \(fires)")
		return fires.map { $0.urlPath }
	}
	
	static
	func
	fetchFireDetail(for inIncidentURL: String)
		async
		throws
		-> Fire
	{
		print("Fetching fire detail for \(inIncidentURL)")
		
		var comps = URLComponents(string: "https://www.fire.ca.gov/api/sitecore/Incident/GetSingleFire")!
		comps.queryItems =
		[
			URLQueryItem(name: "IncidentUrl", value: inIncidentURL)
		]
		let endpoint = comps.url!
		let req = URLRequest(url: endpoint)
		let (data, _) = try await URLSession.shared.data(for: req)
//		print("resp: \(String(data: data, encoding: .utf8) ?? "")")
		let fire = try JSONDecoder().decode(Fire.self, from: data)
		print("\(fire.name) last updated: \(fire.updated)")
//		print("Fire: \(fire)")
		return fire
	}
	
	func
	format(fires inFires: [Fire])
		async
		throws
		-> [[Int]]
	{
		let endpoint = URL(string: "https://vbml.vestaboard.com/compose")!
		var req = URLRequest(url: endpoint)
		req.httpMethod = "POST"
		req.addValue("application/json", forHTTPHeaderField: "Content-Type")
		var comps = [VBMLComponent]()
		comps.append(VBMLComponent(style: VBMLStyle(align: "top", justify: "left", width: 22, height: 1), template: "Fire         Area Cont"))
		
		let kAcreFormatter = NumberFormatter()
		kAcreFormatter.maximumFractionDigits = 1
		kAcreFormatter.minimumFractionDigits = 1
		
		let acreFormatter = NumberFormatter()
		acreFormatter.maximumFractionDigits = 0
		
		var latestUpdated : Date?
		for fire in inFires
		{
			let name = fire.name.components(separatedBy: " ").first!
			comps.append(VBMLComponent(style: VBMLStyle(align: "top", justify: "left", width: 10, height: 1), template: "\(name)"))
			var acres = fire.acresBurned
			var acresString: String
			if acres < 1000
			{
				acresString = acreFormatter.string(from: acres as NSNumber)!
			}
			else
			{
				acres /= 1000.0
				acresString = "\(kAcreFormatter.string(from: acres as NSNumber)!)K"
			}
			
			comps.append(VBMLComponent(style: VBMLStyle(align: "top", justify: "right", width: 7, height: 1), template: "\(acresString)"))
			comps.append(VBMLComponent(style: VBMLStyle(align: "top", justify: "right", width: 5, height: 1), template: "\(Int(fire.containment))%"))
			print(String(format: "%10@, %@, %4d%%", name, acresString, Int(fire.containment)))
			
			if latestUpdated == nil || latestUpdated! < fire.updated
			{
				latestUpdated = fire.updated
			}
		}
//		comps.append(VBMLComponent(style: VBMLStyle(align: "top", justify: "left", width: 22, height: 1), template: "                      "))
		
		if let latestUpdated
		{
//			let updateFormatter = DateFormatter()
			let updateFormatter = RelativeDateTimeFormatter()
//			updateFormatter.dateFormat = "yyyy-MM-dd"
			let update = updateFormatter.string(for: latestUpdated)!
			let height = 4 - inFires.count + 1
			comps.append(VBMLComponent(style: VBMLStyle(align: "bottom", justify: "left", width: 7, height: height), template: "Updated"))
			comps.append(VBMLComponent(style: VBMLStyle(align: "bottom", justify: "right", width: 22-7, height: height), template: "\(update)"))
			print("Updated \(update)")
		}
		
		let vbml = VBML(components: comps)
		let json = try JSONEncoder().encode(vbml)
		req.httpBody = json
//		print("VBML: \(String(data: json, encoding: .utf8) ?? "")")
		
		let (data, _) = try await URLSession.shared.data(for: req)
//		print("resp: \(String(data: data, encoding: .utf8) ?? "")")
		let codes = try JSONDecoder().decode([[Int]].self, from: data)
		print("Codes: \(codes)")
		return codes
	}
	
	mutating
	func
	sendMessage(codes inCodes: [[Int]])
		async
		throws
	{
		if self.lastCodesSent == inCodes
		{
			print("Skipping board updates because codes are the same")
			return
		}
		
		self.lastCodesSent = inCodes
		
		let endpoint = URL(string: "https://rw.vestaboard.com/")!
		var req = URLRequest(url: endpoint)
		req.httpMethod = "POST"
		req.addValue("178bda24+6f97+4178+8f98+e2a3ec0f8c3c", forHTTPHeaderField: "X-Vestaboard-Read-Write-Key")
		req.addValue("application/json", forHTTPHeaderField: "Content-Type")

		let json = try JSONEncoder().encode(inCodes)
		req.httpBody = json
		
		let (data, resp) = try await URLSession.shared.data(for: req)
		print("sendMessage resp: \((resp as! HTTPURLResponse).statusCode) \(String(data: data, encoding: .utf8) ?? "")")
	}
	
	var	lastCodesSent		:	[[Int]]?
}

struct
VBML : Codable
{
	let components	:	[VBMLComponent]
}

struct
VBMLComponent : Codable
{
	let	style		:	VBMLStyle
	let	template	:	String
}

struct
VBMLStyle : Codable
{
	let	align		:	String
	let	justify		:	String
	let	width		:	Int
	let height		:	Int
}

struct
VestaboardCodes : Codable
{
	let	codes	:	[[Int]]
}
