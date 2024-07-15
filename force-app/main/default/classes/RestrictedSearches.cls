/*
 * Mike Ulveling
 * 
 * Utility to return purpose-built SOQLContexts for specific use cases. Queries should be issued thourgh a properly chosen 
 * SOQLContext instance, rather than via Database.query or inline SOQL queries (Apex bracket [] syntax).
 * 
 * Built atop SOQLContext, which itself is built atop SOQLParser, SOQLLexer, RKSecurity, and RKShare:
 */ 
global without sharing class RestrictedSearches {

    global static SOQLContext getStrictPatientLookup() {
        // !! Note how this defaults to a fully strict-mode context when no applicable rule-based metadata matches were found:
        return loadRulesAtopSystemBaseDefaultStrict('LWC - Strict Custom Lookup', Schema.Patient_Visit__c.SObjectType);
    }

    // Creates a new Ruled context layered atop "System Mode" when a metadata match was found, and defaulting to "System Mode"
    // when no match was found:
    global static SOQLContext loadRulesAtopSystemBaseDefaultSystem(String metadataTargetName, Schema.SObjectType targetObjectType) {
        return loadRulesAtopSystemBase(metadataTargetName, targetObjectType, SOQLContext.newSystemMode());
    }

    // Creates a new Ruled context layered atop "System Mode" when a metadata match was found, and defaulting to "Strict Mode"
    // when no match was found:
    global static SOQLContext loadRulesAtopSystemBaseDefaultStrict(String metadataTargetName, Schema.SObjectType targetObjectType) {
        return loadRulesAtopSystemBase(metadataTargetName, targetObjectType, SOQLContext.newStrictMode());
    }

    // Creates a new Ruled context layered atop "System Mode" when a metadata match was found, and defaulting to {defaultNoMatchesContext}
    // when no match was found. If {defaultNoMatchesContext} is null, then an error is thrown when no metadata match is found:
    global static SOQLContext loadRulesAtopSystemBase(String metadataTargetName, 
            Schema.SObjectType targetObjectType, SOQLContext defaultNoMatchesContext) {
        return loadRulesMetadata(metadataTargetName, targetObjectType, SOQLContext.newSystemMode(), defaultNoMatchesContext);
    }

    // Creates a new Ruled context layered atop "Strict Mode" when a metadata match was found, and failing (assertion error)
    // when no match was found:
    global static SOQLContext loadRulesAtopStrictBase(String metadataTargetName, 
            Schema.SObjectType targetObjectType, SOQLContext defaultNoMatchesContext) {
        return loadRulesMetadata(metadataTargetName, targetObjectType, SOQLContext.newStrictMode(), null);
    }

    // Creates a new Ruled context layered atop "Safe Mode" when a metadata match was found, and failing (assertion error)
    // when no match was found:
    global static SOQLContext loadRulesAtopSafeBase(String metadataTargetName, 
            Schema.SObjectType targetObjectType, SOQLContext defaultNoMatchesContext) {
        return loadRulesMetadata(metadataTargetName, targetObjectType, SOQLContext.newSafeMode(), null);
    }

    // Creates a new Ruled context layered atop {ruledBaseContext} when a metadata match was found, and defaulting to 
    // {defaultNoMatchesContext} when no match was found:
    global static SOQLContext loadRulesMetadata(String metadataTargetName, 
            Schema.SObjectType targetObjectType, SOQLContext ruledBaseContext, SOQLContext defaultNoMatchesContext) {
        
        final String objectApiName = '' + targetObjectType;
        String[] generalUserScopes = new String[]{ 'All Users' };
        if (UserInfo.getUserType() == 'Guest') {
            generalUserScopes.add('Guest Users');
        }
        Restricted_Search__mdt[] candidates = [ 
            SELECT MasterLabel, DeveloperName, Target__c, Query_Mode__c, User_Scope__c, Object_Type__c, Minimum_Matches__c
            FROM Restricted_Search__mdt 
            WHERE Object_Type__r.QualifiedApiName = :objectApiName 
                AND Target__c = :metadataTargetName
                AND User_Scope__c IN :generalUserScopes
                // !! OR conditions are not currently supported on Metadata queries. WTF?! Who at SF was asleep at the 
                // wheel when they built this crap. Scuttling "Specific User" facility for now...
                //AND (User_Scope__c IN :generalUserScopes
                //    OR (User_Scope__c = 'Specific User' AND Specific_User_Id__c = :UserInfo.getUserId()))
        ];
        // !! TODO:
        // At some point we need to have a discussion with product on 2 alternatives: 
        // 1. Should Restricted Search configuration loading hone in on a singular metadata match per application, using 
        //    specificity rules (tie-breakers) to choose among multiple candidates, with an ambuguity error thrown if/when 
        //    no clear choice can be made?
        // 2. Alternatively, we could add each candidate config record as its own Rule into a single SOQLContext. The net 
        //    result being that ALL RestrictedSearch configs are enforced (alternatively: allow MATCH ANY versus MATCH ALL)
        // 3. We probably won't need this level of control anytime soon. Choosing option 1. for now.

        // If we got multiple metadata matches, rank them first by the MOST specific match criteria, and then by the LEAST 
        // restrictive search rules:
        Restricted_Search__mdt bestMatch;
        double bestMatchRank = -1;
        for (Restricted_Search__mdt candidate: candidates) {
            double rank = rankSpecificity(candidate);
            if (rank > bestMatchRank) {
                bestMatch = candidate;
                bestMatchRank = rank;
            }
            // TODO: optionally, we can throw a configError (Ambiguous Definition) if we get 2 or more candidates 
            // with the same rank...
            //else if (rank == bestMatchRank) {
            //    throw new AmbiguousRestrictedSearchException();
            //}
        }

        if (bestMatch != null) {
            SOQLContext ruledContext = ruledBaseContext != null 
                ? ruledBaseContext.fork(
                    '' + Restricted_Search__mdt.Schema.SObjectType + '.' + bestMatch.DeveloperName, 
                    'Restricted Search [' + bestMatch.MasterLabel + ']') 
                : SOQLContext.newSystemMode();
            
            SOQLContext.RestrictedToExactMatches rule = 
                new SOQLContext.RestrictedToExactMatches(bestMatch.MasterLabel, targetObjectType);
            ruledContext.addRule(rule);
            // !! For now we layer restriction rules atop "System Mode" of operation, however we may wish to offer the option 
            // of adding atop "Strict Mode":
            ruledContext.systemCrudFLS();
            ruledContext.systemSharing();
            if (bestMatch.Minimum_Matches__c != null) {
                rule.setMinimumMatches(bestMatch.Minimum_Matches__c.intValue());
            }

            // Query related child fields metadata:
            for (Restricted_Search_Field__mdt fieldMeta : [ 
                    SELECT DeveloperName, Applies_to_Minimum_Matches__c, Required__c, Search_Field__r.QualifiedApiName 
                    FROM Restricted_Search_Field__mdt 
                    WHERE Restricted_Search__r.DeveloperName = :bestMatch.DeveloperName ]) {
                // Add field-level rules via SOQLContext.addExactMatchElement() and/or .addFreestyleElement():
                if (fieldMeta.Applies_to_Minimum_Matches__c == true) {
                    rule.addExactMatchElement(fieldMeta.Search_Field__r.QualifiedApiName, fieldMeta.Required__c == true);
                } else {
                    // !! The "allowNested" and "allowAnyOp" arguments are hardcoded to false for now, but we may 
                    // choose to externalize these as metadata fields later on:
                    rule.addFreestyleElement(fieldMeta.Search_Field__r.QualifiedApiName, false, false);
                }
            }

            return ruledContext;
        }

        Assert.isNotNull(defaultNoMatchesContext, 'No Restricted Search definition found for "' + 
            metadataTargetName + '" on Object ' + targetObjectType);
        return defaultNoMatchesContext;
    }

    private static double rankSpecificity(Restricted_Search__mdt candidate) {
        double specificity;
        // Primarily, give a higher rank to more specifically-targeted searches:
        switch on candidate.User_Scope__c {
            when 'Specific User' {
                specificity = 2.0;
            }
            when 'Guest Users' {
                specificity = 1.0;
            } 
            when else {
                specificity = 0.0;
            }
        }
        // Secondarily, give a higher rank to less-restricted (broader) searches:
        if (candidate.Query_Mode__c == 'Without Sharing') {
            specificity += 0.1;
        }
        if (candidate.Minimum_Matches__c == null || candidate.Minimum_Matches__c == 0.0) {
            specificity += 0.1;
        } else {
            specificity += 1.0 / (10.0 + Math.abs(candidate.Minimum_Matches__c));
        }
        return specificity;
    }
}
