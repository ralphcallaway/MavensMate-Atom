trigger MatchPointTrigger on Point__c (after insert) {
	Point__c[] points = trigger.new;
	
	List<Id> matchIds = new List<Id>();
	for(Point__c point : points)
	{
		matchIds.add(point.Match__c);
	}

	System.debug(matchIds);
	Map<Id, Match__c> matches = new Map<Id, Match__c>([SELECT Id, 
															  Match__c.Player1__r.Id, 
															  Match__c.Player2__r.Id 
														 FROM Match__c 
														WHERE Id IN :matchIds 
														  AND (Player_1_Points__c = 11
														  	   OR Player_2_Points__c = 11) ] );


	List<Player__c> players = [SELECT Id FROM Player__c];

	if (players.size() > 2){			
		Integer maxPlayerIndex = players.size();
		List<Match__c> finishedMatches = matches.values();
		List<Match__c> newMatches = new List<Match__c>();
		for(Match__c match : finishedMatches){
			Player__c player1 = match.Player1__r;
			Player__c player2 = match.Player2__r;

			Player__c player1Challenger = null;
			while (player1Challenger == null){
				Integer playerIndex = (Integer)(Math.random() * (Double)maxPlayerIndex);

				if(players[playerIndex].Id != player1.Id && players[playerIndex].Id != player2.Id){
					player1Challenger = players[playerIndex];
				}
			}

			Player__c player2Challenger = null;
			while (player2Challenger == null){
				Integer playerIndex = (Integer)(Math.random() * (Double)maxPlayerIndex);

				if(players[playerIndex].Id != player1.Id && players[playerIndex].Id != player2.Id){
					player2Challenger = players[playerIndex];
				}
			}

			Match__c newMatch = new Match__c();
			newMatch.Player1__c = player1.Id;
			newMatch.Player2__c = player1Challenger.Id;
			newMatches.add(newMatch);

			newMatch = new Match__c();
			newMatch.Player1__c = player2.Id;
			newMatch.Player2__c = player2Challenger.Id;
			newMatches.add(newMatch);
		}
		insert newMatches;
	}

}