import ExpoModulesCore
import SystemConfiguration
import Network
import CoreTelephony

public final class NetworkModule: Module {
  private let monitor = NWPathMonitor()
  private let monitorQueue = DispatchQueue.global(qos: .default)

  public func definition() -> ModuleDefinition {
    Name("ExpoNetwork")

    OnCreate {
      monitor.start(queue: monitorQueue)
    }

    AsyncFunction("getIpAddressAsync") { () -> String? in
      return try getIPAddress()
    }

    AsyncFunction("getNetworkStateAsync") {
      return getNetworkStateAsync()
    }

    OnDestroy {
      monitor.cancel()
    }
  }

  private func getIPAddress() throws -> String {
    var address = "0.0.0.0"
    var ifaddr: UnsafeMutablePointer<ifaddrs>?

    let error = getifaddrs(&ifaddr)

    guard error == 0 else {
      throw IpAddressException(error)
    }

    guard let firstAddr = ifaddr else {
      return address
    }

    for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
      let temp = ifptr.pointee
      let family = temp.ifa_addr.pointee.sa_family

      if family == UInt8(AF_INET) {
        let name = String(cString: temp.ifa_name)
        if name == "en0" || name == "en1" {
          var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
          getnameinfo(
            temp.ifa_addr,
            socklen_t(temp.ifa_addr.pointee.sa_len),
            &hostname,
            socklen_t(hostname.count),
            nil,
            socklen_t(0),
            NI_NUMERICHOST)
          address = String(cString: hostname)
        }
      }
    }

    freeifaddrs(ifaddr)
    return address
  }

  private func getNetworkStateAsync() -> [String: Any?] {
    let path = monitor.currentPath
    let isConnected = path.status == .satisfied
    var currentNetworkType = NetworkType.unknown

    if !isConnected {
      return [
        "type": NetworkType.none.description,
        "isConnected": isConnected,
        "isInternetReachable": isConnected,
        "details": nil
      ]
    }

    let connectionType = NWInterface
      .InterfaceType
      .allCases
      .filter { path.usesInterfaceType($0) }
      .first

    switch connectionType {
    case .wifi:
      currentNetworkType = .wifi
    case .cellular:
      currentNetworkType = .cellular
    case .wiredEthernet:
      currentNetworkType = .ethernet
    default:
      currentNetworkType = .unknown
    }

    return [
      "type": currentNetworkType.description,
      "isConnected": isConnected,
      "isInternetReachable": isConnected,
      "details": getDetailsForNetworkType(networkType: currentNetworkType)
    ]
  }

  private func getDetailsForNetworkType(networkType: NetworkType) -> [String: Any]? {
    let path = monitor.currentPath
    var details = ["isConnectionExpensive": path.isExpensive] as [String: Any]

    switch networkType {
    case .wifi,
      .ethernet:
      details["subnet"] = getSubnetMask()
      return details
    case .cellular:
      details["cellularGeneration"] = getCellularGeneration()
      return  details
    default:
      return nil
    }
  }

  private func getCellularGeneration() -> NetworkCellularGeneration {
    let networkInfo = CTTelephonyNetworkInfo()

    guard let serviceCurrentRadioAccessTechnology = networkInfo.serviceCurrentRadioAccessTechnology else {
      return NetworkCellularGeneration.unknown
    }

    for (_, radioTech) in serviceCurrentRadioAccessTechnology {
      if #available(iOS 14.1, *) {
        if radioTech == CTRadioAccessTechnologyNRNSA || radioTech == CTRadioAccessTechnologyNR {
          return NetworkCellularGeneration.cellularGen5g
        }
      }

      switch radioTech {
      case CTRadioAccessTechnologyGPRS,
        CTRadioAccessTechnologyEdge,
      CTRadioAccessTechnologyCDMA1x:
        return NetworkCellularGeneration.cellularGen2g
      case CTRadioAccessTechnologyWCDMA,
        CTRadioAccessTechnologyHSDPA,
        CTRadioAccessTechnologyHSUPA,
        CTRadioAccessTechnologyCDMAEVDORev0,
        CTRadioAccessTechnologyCDMAEVDORevA,
        CTRadioAccessTechnologyCDMAEVDORevB,
      CTRadioAccessTechnologyeHRPD:
        return NetworkCellularGeneration.cellularGen3g
      case CTRadioAccessTechnologyLTE:
        return NetworkCellularGeneration.cellularGen4g
      default:
        return NetworkCellularGeneration.unknown
      }
    }

    return NetworkCellularGeneration.unknown
  }

  private func getSubnetMask() -> String? {
    var addresses = [String: String]()

    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
      return nil
    }

    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
      let interface = ptr.pointee
      let addrFamily = interface.ifa_addr.pointee.sa_family

      if addrFamily == UInt8(AF_INET) {
        let name = String(cString: interface.ifa_name)

        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(interface.ifa_addr,
                    socklen_t(interface.ifa_addr.pointee.sa_len),
                    &hostname,
                    socklen_t(hostname.count),
                    nil,
                    socklen_t(0),
                    NI_NUMERICHOST)
        let address = String(cString: hostname)

        var netmask = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        getnameinfo(interface.ifa_netmask,
                    socklen_t(interface.ifa_netmask.pointee.sa_len),
                    &netmask,
                    socklen_t(netmask.count),
                    nil,
                    socklen_t(0),
                    NI_NUMERICHOST)
        let subnetMask = String(cString: netmask)

        addresses[name] = subnetMask
      }
    }

    freeifaddrs(ifaddr)

    return addresses["en0"]
  }
}
