//
//  ViewController.swift
//  nav demo
//
//  Created by Jill Cardamon on 7/19/20.
//

import UIKit
import Mapbox
import MapboxCoreNavigation
import MapboxNavigation
import MapboxDirections
import MapboxSearch
import MapboxSearchUI

class ViewController: UIViewController, MGLMapViewDelegate {
    var mapView: NavigationMapView!
    var routeOptions: NavigationRouteOptions?
    var route: Route?
    var startButton: UIButton?
    
    let searchController = MapboxSearchController()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        mapView = NavigationMapView(frame: view.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mapView)
        
        mapView.delegate = self
        searchController.delegate = self
        let panelController = MapboxPanelController(rootViewController: searchController)
        addChild(panelController)
        
        // Allow the map to display the users location.
        mapView.showsUserLocation = true
        mapView.setUserTrackingMode(.follow, animated: true, completionHandler: nil)
        
        // Add a gesture recognizer to the map view
//        let longPress = UILongPressGestureRecognizer(target: self, action: #selector (didLongPress(_:)))
//        mapView.addGestureRecognizer(longPress)
        
//        // put a start button in
//        startButton = UIButton()
//        startButton?.setTitle("Start Navigation", for: .normal)
//        startButton?.translatesAutoresizingMaskIntoConstraints = false
//        startButton?.backgroundColor = .blue
//        startButton?.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
//

    }
    
//    @objc func didLongPress(_ sender: UILongPressGestureRecognizer) {
//        guard sender.state == .began else { return }
//
//        // Convert points where user did a long press to map coordinates
//        let point = sender.location(in: mapView)
//        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
//
//        if let origin = mapView.userLocation?.coordinate {
//            // Calculate the route from the user's location to the set location
//            calculateRoute(from: origin, to: coordinate)
//        } else {
//            print("Failed to get user location, make sure to allow location access for this application.")
//        }
//
//    }
    
    func showAnnotation(_ annotations: [MGLAnnotation], isPOI: Bool) {
        guard !annotations.isEmpty else { return }
        
        if let existingAnnotations = mapView.annotations {
            mapView.removeAnnotations(existingAnnotations)
        }
        mapView.addAnnotations(annotations)
        
        if annotations.count == 1, let annotation = annotations.first {
            mapView.setCenter(annotation.coordinate, zoomLevel: 15, animated: true)
        } else {
            mapView.showAnnotations(annotations, animated: true)
        }
    }
    
    // Display search results
    func displaySearchResults(_ results: [SearchResult]) {
        let annotations = results.map({result -> MGLAnnotation in
            let pointAnnotation = MGLPointAnnotation()
            pointAnnotation.title = result.name
            pointAnnotation.subtitle = result.address?.formattedAddress(style: .medium)
            pointAnnotation.coordinate = result.coordinate
            
            return pointAnnotation
        })
        mapView.addAnnotations(annotations)
        mapView.showAnnotations(annotations, animated: true)
    }
    
    // Calculate route to be used for navigation
    func calculateRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        // Coordinate accuracy is how close the route must come to the waypoint in order to be considered viable. It is measured in meters. A negative value indicates that the route is viable regardless of how far the route is from the waypoint.
        let origin = Waypoint(coordinate: origin, coordinateAccuracy: -1, name: "Start")
        let destination = Waypoint(coordinate: destination, coordinateAccuracy: -1, name: "Finish")

        // Specify that the route is intended for automobiles avoiding traffic
        let routeOptions = NavigationRouteOptions(waypoints: [origin, destination], profileIdentifier: .automobileAvoidingTraffic)

        // Generate the route object and draw it on the map
        Directions.shared.calculate(routeOptions) { [weak self] (session, result) in
            switch result {
            case .failure(let error):
                print(error.localizedDescription)
            case .success(let response):
                guard let route = response.routes?.first, let strongSelf = self else {
                    return
                }
                
                strongSelf.route = route
                strongSelf.routeOptions = routeOptions
                
                // Draw the route on the map after creating it
                strongSelf.drawRoute(route: route)
                
                // Show destination waypoint on the map
                strongSelf.mapView.showWaypoints(on: route)
                
                // Display callout view on destination annotation
                if let annotation = strongSelf.mapView.annotations?.first as? MGLPointAnnotation {
                    annotation.title = "Start navigation"
                    strongSelf.mapView.selectAnnotation(annotation, animated: true, completionHandler: nil)
                }
            }
        }
    }

    func drawRoute(route: Route) {
        guard let routeShape = route.shape, routeShape.coordinates.count > 0 else { return }
        
        // Convert the route's coordinates into a polyline
        var routeCoordinates = routeShape.coordinates
        let polyline = MGLPolylineFeature(coordinates: &routeCoordinates, count: UInt(routeCoordinates.count))
        
        // If there's already a route line on the map, reset its shape to the new route
        if let source = mapView.style?.source(withIdentifier: "route-source") as? MGLShapeSource {
            source.shape = polyline
        } else {
            let source = MGLShapeSource(identifier: "route-source", features: [polyline], options: nil)
            
            // Customize the route line color and width
            let lineStyle = MGLLineStyleLayer(identifier: "route-style", source: source)
            lineStyle.lineColor = NSExpression(forConstantValue: #colorLiteral(red: 0.1897518039, green: 0.3010634184, blue: 0.7994888425, alpha: 1))
            lineStyle.lineWidth = NSExpression(forConstantValue: 3)
            
            // Add source and style layer of the route line to the map
            mapView.style?.addSource(source)
            mapView.style?.addLayer(lineStyle)
        }
    }
    
    // Implement the delegate method that allows annotations to show callouts when tapped
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    // Present the navigation view controller when the callout is selected
    func mapView(_ mapView: MGLMapView, tapOnCalloutFor annotation: MGLAnnotation) {
        guard let route = route, let routeOptions = routeOptions else {
            return
        }
        
        let navigationViewController = NavigationViewController(for: route, routeOptions: routeOptions)
        navigationViewController.modalPresentationStyle = .fullScreen
        self.present(navigationViewController, animated: true, completion: nil)
    }
}

extension ViewController: SearchControllerDelegate {
    func categorySearchResultsReceived(results: [SearchResult]) {
        
        let annotations = results.map { searchResult -> MGLPointAnnotation in
            let annotation = MGLPointAnnotation()
            annotation.coordinate = searchResult.coordinate
            annotation.title = searchResult.name
            annotation.subtitle = searchResult.address?.formattedAddress(style: .medium)
            
            return annotation
        }
        showAnnotation(annotations, isPOI: false)
    }
    
    func searchResultSelected(_ searchResult: SearchResult) {
        let annotation = MGLPointAnnotation()
        annotation.coordinate = searchResult.coordinate
        annotation.title = searchResult.name
        annotation.subtitle = searchResult.address?.formattedAddress(style: .medium)
        
        showAnnotation([annotation], isPOI: searchResult.type == .POI)
    }
    
    func userFavoriteSelected(_ userFavorite: FavoriteRecord) {
        let annotation = MGLPointAnnotation()
        annotation.coordinate = userFavorite.coordinate
        annotation.title = userFavorite.name
        annotation.subtitle = userFavorite.address?.formattedAddress(style: .medium)
        
        showAnnotation([annotation], isPOI: true)
    }
}
