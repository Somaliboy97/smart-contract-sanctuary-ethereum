// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.9;

contract Student_listV3 {
    struct Student {
        string name;
        uint rollno;
        string class;
        string batch;
      
        
    }
    mapping( uint =>Student) public Studentlist;
    
    uint public STUDENT;
    uint rollcount;
    address manager;
    bool private isInitialized ;

    function initialize() external {
        require(!isInitialized , "Function already initialized");
        manager = msg.sender;
        isInitialized =true;
    }
    
    function create(string memory _name,uint _rollno,string memory _class,string memory _batch) public {
         require(_rollno != rollcount ,"To Update go To Update Details");
         Studentlist[_rollno] = Student(_name,_rollno,_class,_batch);
            if (rollcount >0){
             assert(_rollno == rollcount+1 );   
             
         STUDENT++;
         rollcount = _rollno;
            }else{
                 STUDENT++;
         rollcount = _rollno;
            }

    }
     function updatedetails( string memory _name,uint _rollno,string memory _class,string memory _batch) public {
         require (msg.sender ==manager,"Only Manager Can Update Details");
         require(STUDENT>0,"Create id First");
         Student storage s1 = Studentlist[_rollno];
         s1.name = _name;
         s1.rollno =_rollno;
         s1.class = _class;
         s1.batch= _batch;


    }

}