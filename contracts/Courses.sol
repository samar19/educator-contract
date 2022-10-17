// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@tableland/evm/contracts/ITablelandTables.sol";
import {ISuperfluid} from "./interfaces/superfluid/ISuperfluid.sol";
import {IConstantFlowAgreementV1} from "./interfaces/agreements/IConstantFlowAgreementV1.sol";
import {ISuperfluidToken} from "./interfaces/superfluid/ISuperfluidToken.sol";
import {CFAv1Library} from "./apps/CFAv1Library.sol";

contract Courses is ERC1155 {
    using Counters for Counters.Counter;
    using CFAv1Library for CFAv1Library.InitData;

    //initialize cfaV1 variable
    CFAv1Library.InitData public cfaV1;

    ITablelandTables private _tableland;
    string private _tablePrefix = "coursalize";

    // Courses
    struct Course {
        uint256 price;
        address instructor;
    }

    string private _courseTable;
    uint256 private _courseTableId;
    Counters.Counter public _courseIds;
    mapping(uint256 => Course) public _courses;

    // Lecture Table
    string private _lectureTable;
    uint256 public _lectureTableId;
    Counters.Counter private _lectureIds;

    // Users Table
    string private _userTable;
    uint256 private _userTableId;
    Counters.Counter public _userIds;
    mapping(address => bool) public _users;

    // Reviews Table
    string private _reviewTable;
    uint256 private _reviewTableId;

    string private _baseURIString =
        "https://testnet.tableland.network/query?s=";

    // Sponsors
    struct Sponsor {
        address sender;
        address token;
        uint256 course;
        string metadata;
        int96 flowrate;
    }
    mapping(uint256 => Sponsor[]) sponsors;

    constructor(address registry, ISuperfluid host) ERC1155(_baseURIString) {
        _tableland = ITablelandTables(registry);

        // Course Table
        _courseTableId = _tableland.createTable(
            address(this),
            string.concat(
                "CREATE TABLE ",
                _tablePrefix,
                "_",
                Strings.toString(block.chainid),
                " (id int, title text, category int, description text, cover text, price int, instructor text);"
            )
        );

        _courseTable = string.concat(
            _tablePrefix,
            "_",
            Strings.toString(block.chainid),
            "_",
            Strings.toString(_courseTableId)
        );

        // Lecture Table
        _lectureTableId = _tableland.createTable(
            address(this),
            string.concat(
                "CREATE TABLE ",
                _tablePrefix,
                "_",
                Strings.toString(block.chainid),
                " (id int, courseId int, name text, description text, media text);"
            )
        );

        _lectureTable = string.concat(
            _tablePrefix,
            "_",
            Strings.toString(block.chainid),
            "_",
            Strings.toString(_lectureTableId)
        );

        // Users Table

        _userTableId = _tableland.createTable(
            address(this),
            string.concat(
                "CREATE TABLE ",
                _tablePrefix,
                "_",
                Strings.toString(block.chainid),
                " (id int, display_name text, headline text, bio text, address text, avatar text);"
            )
        );

        _userTable = string.concat(
            _tablePrefix,
            "_",
            Strings.toString(block.chainid),
            "_",
            Strings.toString(_userTableId)
        );

        // Reviews Table
        _reviewTableId = _tableland.createTable(
            address(this),
            string.concat(
                "CREATE TABLE ",
                _tablePrefix,
                "_review",
                "_",
                Strings.toString(block.chainid),
                " (id text, display_name text, headline text, bio text, avatar text);"
            )
        );

        _reviewTable = string.concat(
            _tablePrefix,
            "_review",
            "_",
            Strings.toString(block.chainid),
            "_",
            Strings.toString(_reviewTableId)
        );

        cfaV1 = CFAv1Library.InitData(
            host,
            //here, we are deriving the address of the CFA using the host contract
            IConstantFlowAgreementV1(
                address(
                    host.getAgreementClass(
                        keccak256(
                            "org.superfluid-finance.agreements.ConstantFlowAgreement.v1"
                        )
                    )
                )
            )
        );
    }

    function courseURI() public view returns (string memory) {
        return
            string.concat(_baseURIString, "SELECT%20*%20FROM%20", _courseTable);
    }

    function lectureURI() public view returns (string memory) {
        return
            string.concat(
                _baseURIString,
                "SELECT%20*%20FROM%20",
                _lectureTable
            );
    }

    function userURI() public view returns (string memory) {
        return
            string.concat(_baseURIString, "SELECT%20*%20FROM%20", _userTable);
    }

    function reviewURI() public view returns (string memory) {
        return
            string.concat(_baseURIString, "SELECT%20*%20FROM%20", _reviewTable);
    }

    function setUser(
        string memory _name,
        string memory _headline,
        string memory _bio,
        string memory _avatar
    ) public {
        if (_users[msg.sender] == true) {
            _tableland.runSQL(
                address(this),
                _userTableId,
                string.concat(
                    "UPDATE ",
                    _userTable,
                    " SET display_name = '",
                    _name,
                    "', headline = '",
                    _headline,
                    "', bio = '",
                    _bio,
                    "', avatar = '",
                    _avatar,
                    " ' WHERE address = '",
                    Strings.toHexString(uint160(msg.sender), 20),
                    "';"
                )
            );
        } else {
            uint256 newItemId = _userIds.current();
            _tableland.runSQL(
                address(this),
                _userTableId,
                string.concat(
                    "INSERT INTO ",
                    _userTable,
                    " (id, display_name, headline, bio, address, avatar) VALUES (",
                    Strings.toString(newItemId),
                    ", '",
                    _name,
                    "', '",
                    _headline,
                    "', '",
                    _bio,
                    "', '",
                    Strings.toHexString(uint160(msg.sender), 20),
                    "', '",
                    _avatar,
                    " ')"
                )
            );
            _userIds.increment();
            _users[msg.sender] = true;
        }
    }

    function createCourse(
        string memory _title,
        uint256 _category,
        string memory _description,
        string memory _cover,
        uint256 _price
    ) public {
        require(_users[msg.sender] == true, "complete profile");
        uint256 newItemId = _courseIds.current();
        _tableland.runSQL(
            address(this),
            _courseTableId,
            string.concat(
                "INSERT INTO ",
                _courseTable,
                " (id, title, category, description, cover, price, instructor) VALUES (",
                Strings.toString(newItemId),
                ", '",
                _title,
                "', ",
                Strings.toString(_category),
                ", '",
                _description,
                "', '",
                _cover,
                " ', ",
                Strings.toString(_price),
                ", '",
                Strings.toHexString(uint160(msg.sender), 20),
                "')"
            )
        );
        _courses[newItemId] = Course(_price, msg.sender);
        _courseIds.increment();
    }

    function mintCourse(uint256 _courseId) public payable {
        uint256 nextCourseId = _courseIds.current();
        require(_courseId < nextCourseId, "not defined");
        Course memory course = _courses[_courseId];
        require(msg.value == course.price, "wrong value");
        (bool sent, ) = course.instructor.call{value: msg.value}("");
        require(sent, "faild to pay");
        // mint course for minter
        _mint(msg.sender, _courseId, 1, bytes(""));
    }

    function editCourse(
        uint256 _courseId,
        string memory _title,
        uint256 _category,
        string memory _description,
        string memory _cover,
        uint256 _price
    ) public {
        require(_courseId < _courseIds.current(), "not defined");
        require(_courses[_courseId].instructor == msg.sender, "unauthorized");
        _tableland.runSQL(
            address(this),
            _courseTableId,
            string.concat(
                string.concat(
                    "UPDATE ",
                    _courseTable,
                    " SET title = '",
                    _title,
                    "', category = ",
                    Strings.toString(_category),
                    ", description = '",
                    _description,
                    "', cover = '"
                ),
                string.concat(
                    _cover,
                    " ', price = ",
                    Strings.toString(_price),
                    " WHERE id = ",
                    Strings.toString(_courseId),
                    ";"
                )
            )
        );
        _courses[_courseId] = Course(_price, msg.sender);
    }

    function addLecture(
        uint256 _courseId,
        string memory _name,
        string memory _description,
        string memory _media
    ) public {
        require(_courseId < _courseIds.current(), "not defined");
        require(_courses[_courseId].instructor == msg.sender, "unauthorized");
        uint256 newItemId = _lectureIds.current();
        _tableland.runSQL(
            address(this),
            _lectureTableId,
            string.concat(
                "INSERT INTO ",
                _lectureTable,
                " (id, courseId, name, description, media) VALUES (",
                Strings.toString(newItemId),
                ",",
                Strings.toString(_courseId),
                ", '",
                _name,
                "', '",
                _description,
                "', '",
                _media,
                " ')"
            )
        );
        _lectureIds.increment();
    }

    function sponsorCourse(
        uint256 _courseId,
        address _token,
        int96 _flowrate,
        string memory _metadata
    ) public {
        require(_courseId < _courseIds.current(), "not defined");

        Sponsor[] storage courseSponsors = sponsors[_courseId];

        courseSponsors.push(
            Sponsor(msg.sender, _token, _courseId, _metadata, _flowrate)
        );

        cfaV1.createFlow(
            _courses[_courseId].instructor,
            ISuperfluidToken(_token),
            _flowrate
        );
    }

    function getCourseSponsors(uint256 _courseId)
        public
        view
        returns (Sponsor[] memory courseSponsors)
    {
        courseSponsors = sponsors[_courseId];
    }
}
