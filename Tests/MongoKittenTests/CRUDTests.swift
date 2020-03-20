import MongoKitten
import NIO
import XCTest

#if canImport(NIOTransportServices)
import NIOTransportServices
let loop = NIOTSEventLoopGroup(loopCount: 1, defaultQoS: .default).next()
#else
let loop = MultiThreadedEventLoopGroup(numberOfThreads: 1).next()
#endif

class CRUDTests : XCTestCase {
    let settings = try! ConnectionSettings("mongodb://localhost:27017")
    var db: MongoConnection!
    var test: MongoDatabase!
    var usersCollection: MongoCollection!

    override func setUp() {
        db = try! MongoConnection.connect(settings: settings, on: loop).wait()
        test = db["test"]
        usersCollection = test["users"]
    }
    
    override func tearDown() {
        try! usersCollection.drop().wait()
    }
    
    func testListDatabases() throws {
        try XCTAssertTrue(db.listDatabases().wait().contains { $0.name == "admin" })
    }

    func testInsert() {
        let user = User(named: "peter", password: "password")
        let result = try! usersCollection.insert(BSONEncoder().encode(user)).wait()
        XCTAssertEqual(result.ok, 1)
        XCTAssertEqual(result.insertCount, 1)

    }
    
    func testFind(){
        let user = User(named: "jane", password: "secret")
        try! usersCollection.insert(BSONEncoder().encode(user)).wait()
        if let newUser = try! usersCollection.findOne("name" == user.name, as: User.self).wait() {
            XCTAssertEqual(user.name, newUser.name)
             XCTAssertEqual(user.password, newUser.password)
            XCTAssertEqual(user._id, newUser._id)
        } else {
            XCTFail()
        }
    }
    
    func testUpdate(){
        let user = User(named: "carlo", password: "not hashed")
        try! usersCollection.insert(BSONEncoder().encode(user)).wait()
        let result = try! usersCollection.updateOne(where: ["name": user.name], setting: ["password": "updated password"], unsetting: nil).wait()
        if let updatedUser = try! usersCollection.findOne("name" == user.name, as: User.self).wait() {
            XCTAssertEqual(user.name, updatedUser.name)
            XCTAssertEqual("updated password", updatedUser.password)
            XCTAssertEqual(user._id, updatedUser._id)
        } else {
            XCTFail()
        }
    }
    
    func testDelete(){
        let user = User(named: "peter deleter", password: "unknown")
        try! usersCollection.insert(BSONEncoder().encode(user)).wait()
        let userCountBeforeDelete = try! usersCollection.count().wait()
        try! usersCollection.deleteOne(where: "name" == user.name).wait()
        let userCountAfterDelete = try! usersCollection.count().wait()
        XCTAssertEqual(1, userCountBeforeDelete)
        XCTAssertEqual(0, userCountAfterDelete)
    }
}

struct User: Codable {
    let _id: ObjectId
    let name: String
    var password: String


    init(named name: String, password: String) {
        self._id = ObjectId()
        self.name = name
        self.password = password
    }
}
