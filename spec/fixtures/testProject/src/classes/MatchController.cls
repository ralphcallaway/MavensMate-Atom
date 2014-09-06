public with sharing class MatchController {

    private final List<Match__c> matches;

    public String pointMatchId { get; set; }
    public String pointScorerId { get; set; }
    public ApexPages.StandardSetController stdController { get; set; }

    public MatchController(ApexPages.StandardSetController ctrl) {
        this.matches = ctrl.getSelected();
        stdController = ctrl;
    }

    public PageReference pointScored(){
        Match__c pointMatch = [SELECT Id, Player1__r.Id, Player2__r.Id, Player_1_Serving__c FROM Match__c WHERE Id = :pointMatchId LIMIT 1];
        Point__c point = new Point__c();

        point.Winner__c = (Id)pointScorerId;
        point.Match__c = pointMatch.Id;

        if (pointMatch.Player_1_Serving__c){
            point.Server__c = pointMatch.Player1__r.Id;
        } else {
            point.Server__c = pointMatch.Player2__r.Id;
        }
        System.debug('whats up');
        insert point;

        if(!Test.isRunningTest()){
            stdController.reset();
        }

        return null;
    }
}