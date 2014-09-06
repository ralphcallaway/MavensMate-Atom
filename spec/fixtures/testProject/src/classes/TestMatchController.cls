@isTest
private class TestMatchController {
	
		@isTest static void match_controller_point_scored_adds_point() {


		Player__c player1 = new Player__c();
		player1.Name = 'test player 1';

		Player__c player2 = new Player__c();
		player2.Name = 'test player 2';

		insert player1;
		insert player2;

		Match__c match = new Match__c();

		match.Player1__c = player1.Id;
		match.Player2__c = player2.Id;

		insert match;

		List<Match__c> matches = new List<Match__c>();
		matches.add(match);

		MatchController theController = new MatchController(new ApexPages.StandardSetController(matches));
		theController.pointMatchId = match.Id;
		theController.pointScorerId = player2.Id;

		theController.pointScored();

		List<Point__c> matchPoints = [SELECT Id, Server__c, Winner__c FROM Point__c WHERE Match__c = :match.Id];

		System.assertEquals(1, matchPoints.size());
		System.assertEquals(player2.Id, matchPoints[0].Winner__c);
	}
	
}