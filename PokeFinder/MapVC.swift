//
//  MapVC.swift
//  PokeFinder
//
//  Created by 呂易軒 on 2017/11/22.
//  Copyright © 2017年 呂易軒. All rights reserved.
//

/*

 MKMapView - displays the map and manages annotations.
 MKMapViewDelegate - you return data from specific functions to MKMapView.
 MKAnnotation - contains data about a location on the map.
 MKAnnotationView - displays an annotation.
 
*/


import UIKit
import FirebaseDatabase

// insert protocol
class MapVC: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var ballBtn: UIButton!
    
    // work with location so we need this
    let locationManager = CLLocationManager()
    //let currentLocation: CLLocation! = nil  //不用用到這個, mapView直接有userLocation
    // 再加上 mapView.userTrackingMode = MKUserTrackingMode.follow 即可

    
    var mapHasCenteredInBeginning = false
    
    var geoFire: GeoFire!
    
    //Firebase database reference
    var geoFireReference: DatabaseReference!
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        locationAuthStatus()
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.delegate = self
        
        // track the user location
        mapView.userTrackingMode = MKUserTrackingMode.follow
        
        // set the reference to the general satabase your using in the app
        geoFireReference = Database.database().reference()
        geoFire = GeoFire(firebaseRef: geoFireReference)
    }
    
    
    // * authorize or request authorization
    // 放在viewDidAppear, 因為希望這個發生在vieDidLoad之前
    func locationAuthStatus(){
        
        // 沒有點開時不要追蹤
        if CLLocationManager.authorizationStatus() == .authorizedWhenInUse{
            
            mapView.showsUserLocation = true
            
        } else {
            
            // 設定info.plist!!!!!!! privacy - location when in used(pop-out message)
            locationManager.requestWhenInUseAuthorization()
            
            //不能這樣寫，萬一不答應也會跑
            //locationAuthStatus()  //跑if
        }
    }
    
    
    //tell the delegate that the authorization status was changed
    //from CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        
        if status == .authorizedWhenInUse{
            
            mapView.showsUserLocation = true
        }
    }
    
    
    //讓user的location在畫面的正中間
    func centerMapOnLocation(location: CLLocation){
        
        //(2000, 2000) is the region that we want to capture
        let coordinateRegion = MKCoordinateRegionMakeWithDistance(location.coordinate, 1500, 1500)
        
        mapView.setRegion(coordinateRegion, animated: true)
    }
    
    
    // update the callback func for when the user's location is actually updated.
    // whenever the phone updates, we want to center that map (透過 ‘mapView.userTrackingMode = MKUserTrackingMode.follow’)
    // from MKMapViewDelegate
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        
        //這邊處理，when updates come in, 'mapView.userTrackingMode = MKUserTrackingMode.follow' 處理追蹤。
        //然而，又不希望永遠保持追蹤，因為可能會想滑到其他地方看看 -> 第一時間要置中、其他時間按了球球再回來 -> bool 判斷！
        if let userLoc = userLocation.location{
            
            if mapHasCenteredInBeginning == false {
                
                centerMapOnLocation(location: userLoc)
                mapHasCenteredInBeginning = true
            }
        }
    }
    
    
    //from MKMapViewDelegate
    //處理所有跟annotation display有關的事情，所以每當我們加annotation到mapView都要經過此func
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        let annoIdentifier = "Pokemon"
        
        // optional 讓它在不同的狀況有不同的initialization
        var annotationView: MKAnnotationView?
        
        // if this is a user location annotation, we wanna change what's happening inside
        if annotation.isKind(of: MKUserLocation.self){
            
            //更換user標誌 -> 藍色圈圈 -> 小智
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: "User")
            annotationView?.image = UIImage(named: "ash")
            
        //create a generic code to create a reusable annotation
        //reuse our annotation if needed
        } else if let dequeueAnno = mapView.dequeueReusableAnnotationView(withIdentifier: annoIdentifier) {
            
            annotationView = dequeueAnno
            annotationView?.annotation = annotation
        
        //若不能deqeueReuse annotation, 創一個default的annotation
        } else {
            
            let newAnnotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: annoIdentifier)
            
            //We want that pop out to appear with the map icon
            newAnnotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
         
            annotationView = newAnnotationView
        }
        
        
        //any of the cases above happened, customize it
        //前提 1.annotationView is not nil ; annotation 可以成功地被cast as PokeAnnotation
        //＊＊＊＊被cast as某Model, 就等於是某Model了 -> 可呼叫裡面的東西
        if let annotationView = annotationView, let anno = annotation as? PokeAnnotation{
            
            //Once you call this, you need to set title in customize annotation file -> "PokeAnnotation"
            //canShowCallout -> tap it and show the map thing
            annotationView.canShowCallout = true
            annotationView.image = UIImage(named: "\(anno.pokeID)")
            
            let btn = UIButton()
            btn.frame = CGRect(x: 0, y: 0, width: 30, height: 30)
            btn.setImage(UIImage(named: "map"), for: .normal)
            
            annotationView.rightCalloutAccessoryView = btn
        }
        
        
        return annotationView
    }
    
    //store the pokemon by their ID
    //location, pokeID前面可以加一些形容詞
    func createSighting(location: CLLocation, pokeId: Int){
        
        // 當random出來一個pokemon, 呼叫這個func（call geofire firebase）,and it's going to set a gps location for a specific piece of data (where the magic of geofire happened)
        // 已知(已傳入資料庫)地點，並賦予key -> 找到gps location!!!
        geoFire.setLocation(location, forKey: "\(pokeId)")
    }
    
    
    //whenever we got user's location / pokemon location , we show the sighting on the map
    func showSightingOnMap(location: CLLocation){
         
        // create a query (written in documentation) -> 找到pokemon
        // ...GeoFire allows you to query all keys within a geographic area using GFQuery objects.
        let circleQuery = geoFire.query(at: location, withRadius: 2.0)
        
        //just want things to happened and you don't care about the result use _ in lefthand side
        //what we want to do is whenever it finds a key for location we jsut want to show it. -> keyEntered
        
        //do 'observe' whenever we find a sighting
        _ = circleQuery?.observe(GFEventType.keyEntered, with: {(key: String!, location: CLLocation!) in
        
            //key跟location可能會是nil, 所以要if let一下
            if let foundKey = key, let foundLocation = location{
                
                // using our customed annotation to create an annotation
                // passing in very specific pokemon in very specific location 
                let annotation = PokeAnnotation(coordinate: foundLocation.coordinate, pokeID: Int(foundKey)!)
                
                self.mapView.addAnnotation(annotation)
                
                //一旦呼叫addAnnotation, viewForAnnotatio也會被呼叫 -> customize it 看你到底要它是什麼 -> 再DISPLAY到 mapView
            }
        })
        
    }
    
    //MKMap的callback function
    //radius只有2.5km, 但當我滑到其他地方時，我也想要pokemon跳出來
    //when the region is changing, we want also want the map to update for displaying pokemon
    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
        
        //grabing the location whereever the center of the map is
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        showSightingOnMap(location: loc)
    }
    
    //MKMap的callback function
    //tap popped-out pokemon再tap map -> open Apple maps to show direction
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        
        
        // configure the map before we load it.
        if let anno = view.annotation as? PokeAnnotation {
            
            // ***apple map things
            // coordinate -> something deal with latitude and logitude
            // Work with apple maps -> palcemark:起點 ； destination:終點
            let place = MKPlacemark(coordinate: anno.coordinate)
            let destination = MKMapItem(placemark: place)
            destination.name = "Pokemon Sighting"
            let regionDistance: CLLocationDistance = 800

            // create a new MKCoordinateRegion from the specific coordinate and distance value
            let regionSpan = MKCoordinateRegionMakeWithDistance(anno.coordinate, regionDistance, regionDistance)
            
            //Dictionary [keys : values]
            //THese are options we can pass into the Apple Maps
            
            //We want the center key centered in the center of the region
            //, How far do you wanna span out
            let options = [MKLaunchOptionsMapCenterKey: NSValue(mkCoordinate: regionSpan.center), MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: regionSpan.span),  MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving] as [String : Any]
            
            //launch the map
            MKMapItem.openMaps(with: [destination], launchOptions: options)
        }
    }
    
    
    //spot random pokemon
    @IBAction func ballBtnPressed(_ sender: Any) {
        
        let loc = CLLocation(latitude: mapView.centerCoordinate.latitude, longitude: mapView.centerCoordinate.longitude)
        
        let randomID = arc4random_uniform(151) + 1
        
        createSighting(location: loc, pokeId: Int(randomID))
    }

}
