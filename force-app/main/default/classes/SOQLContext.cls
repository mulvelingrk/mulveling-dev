/*
 * Mike Ulveling
 * 
 * Closes the loop on our most useful SOQLParser / RKSecurity / RKShare features, and adds configurable Search Restrictions.
 * Queries should be issued thourgh a properly crafted SOQLContext instance, rather than via Database.query or inline SOQL 
 * queries (Apex bracket [] syntax).
 */
global class SOQLContext {
    static SOQLContext DefaultSystemMode;
    static SOQLContext DefaultStrictMode;

    // Static Constructors:

    global static SOQLContext getDefaultSystemMode() {
        if (DefaultSystemMode == null) {
            DefaultSystemMode = new SOQLContext('SystemMode', 'System-Mode')
                .systemSharing()
                .systemCrudFLS();
        }
        return DefaultSystemMode;
    }

    global static SOQLContext getDefaultStrictMode() {
        if (DefaultStrictMode == null) {
            DefaultStrictMode = new SOQLContext('StrictMode', 'Strict-Mode')
            .strictSharing()
            .strictCrudFLS();
        }
        return DefaultStrictMode;
    }

    @TestVisible
    String name;
    @TestVisible
    String label;

    Integer securityMode = RKSecurity.FILTER_FLS_THROW_CRUD;
    Boolean securityModeTransactional = false;
    Boolean enforceCrudFLS = true;

    Set<Schema.sObjectType> recordAccessBypassTypes = new Set<Schema.sObjectType>{ 
        Schema.sObjectType.RecordType.getSObjectType(), // RecordType sObjectType metadata is a bit weird
        Schema.ContentVersion.sObjectType, Schema.ContentDocument.sObjectType, Schema.ContentDocumentLink.sObjectType,
        Schema.Attachment.sObjectType 
    };
    RKShare.AccessResolver customAccess;
    RKShare.SecurityModel sharingModel;

    @testVisible
    RestrictedSearch[] searchRules = new RestrictedSearch[]{};
    
    // New SOQLContext defaults to the following behaviors:
    // * Strict CRUD enforcement (throw error).
    // * Filtered FLS enforcement (e.g. silent removal of unreadable fields from SELECT clauses).
    // * SOQL queries execute in a "with sharing" context, which enforces platform sharing rules.
    // These behaviors can be changed / customized by using the builder methods defined below. 
    global SOQLContext(String name, String label) {
        this.name = name;
        this.label = label;
        this.sharingModel = new RKShare.WithPlatformSharing();
    }

    global SOQLContext(String name) {
        this(name, name);
    }

    global SOQLContext() {
        this('AdHoc');
    }

    // "System Mode" CRUD/FLS. Does not assert CRUD nor FLS.
    global SOQLContext systemCrudFLS() {
        this.securityMode = RKSecurity.BYPASS_FLS_CRUD;
        this.enforceCrudFLS = false;
        return this;
    }

    // "Safe Mode" CRUD/FLS where any violation of either throws an error (i.e. non-silent, as opposed to filtering).
    global SOQLContext strictCrudFLS() {
        this.securityMode = RKSecurity.ALL_OR_NONE;
        return this;
    }

    global SOQLContext strictSharing() {
        this.sharingModel = new RKShare.WithPlatformSharing();
        return this;
    }

    // "System Mode" sharing applies "without sharing" on query execution:
    global SOQLContext systemSharing() {
        // !! READ THE COMMENT ABOVE
        // The purpose of this method is to engage WithOUT Sharing - DO NOT change this to With Sharing:
        this.sharingModel = new RKShare.WithoutPlatformSharing(null);
        return this;
    }

    // "Custom Mode" sharing applies custom RKShare.AccessResover logic in a "without sharing" execution context:
    public SOQLContext customSharing(RKShare.AccessResolver customAccess) {
        this.customAccess = customAccess;
        this.sharingModel = new RKShare.WithoutPlatformSharing(customAccess);
        return this;
    }

    global SOQLContext addRule(RestrictedSearch rule) {
        searchRules.add(rule);
        return this;
    }

    // "Custom Mode" sharing applies custom RKShare.AccessResover logic in a "without sharing" execution context.
    // "designatedUser" should hold Id and Name fields:
    global SOQLContext delegatedSharing(User designatedUser) {
        customSharing(new RKShare.DesignatedUserAccessResolver(recordAccessBypassTypes, designatedUser));
        return this;
    }

    global SObject[] query(String soql, Map<String, Object> namedBinds) {
        return query(soql, namedBinds, null);
    }

    global SObject[] query(String soql, Object[] anonymousBinds) {
        return query(soql, null, anonymousBinds);
    }

    global SObject[] query(String queryString, Map<String, Object> namedBinds, Object[] anonymousBinds) {
        // Works like startSystemMode(), but only acts like System mode with regard to record sharing, not CRUD/FLS:
        RKSecurity.SecuritySavepoint sp = new RKSecurity.SecuritySavepoint();
        try {
            RKSecurity.setSecurityMode(securityMode);
            if (securityModeTransactional) {
                RKSecurity.transactionalThrow();
            }
            
            // Uses a LocalReBindPool, e.g. Id[] ids0, ids1, ids2:
            SOQLParser.LocalRebindPool rebindPool = RKShare.mintRebindPool();
            SOQLParser.SOQL soql = 
                new SOQLParser.SOQL(queryString)
                    .rebindPool(rebindPool)
                    .vals(namedBinds)
                    .vals(anonymousBinds)
                    .resolve(enforceCrudFLS);
            
            assertSearchRestrictions(soql)
                .bind();
            return sharingModel.query(soql.ser(false), rebindPool);
        } finally {
            RKSecurity.restore(sp);
        }
    }

    global String getSafeQuery(String queryString, Map<String, Object> namedBinds, Object[] anonymousBinds, SOQLParser.LocalRebindPool rebindPool) {
        // Works like startSystemMode(), but only acts like System mode with regard to record sharing, not CRUD/FLS:
        RKSecurity.SecuritySavepoint sp = new RKSecurity.SecuritySavepoint();
        try {
            RKSecurity.setSecurityMode(securityMode);
            if (securityModeTransactional) {
                RKSecurity.transactionalThrow();
            }
            
            // Uses a LocalReBindPool, e.g. Id[] ids0, ids1, ids2:
            //SOQLParser.LocalRebindPool rebindPool = RKShare.mintRebindPool();
            SOQLParser.SOQL soql = 
                new SOQLParser.SOQL(queryString);
            if (rebindPool != null) {
                soql.rebindPool(rebindPool);
            }
            soql.vals(namedBinds)
                .vals(anonymousBinds)
                .resolve(enforceCrudFLS);
            
            assertSearchRestrictions(soql)
                .bind();
            //return sharingModel.query(soql.ser(false), rebindPool);
            return soql.ser(false);
        } finally {
            RKSecurity.restore(sp);
        }
    }

    // throws RestrictedSearchException:
    global SOQLParser.SOQL validate(String queryString) {
        // Works like startSystemMode(), but only acts like System mode with regard to record sharing, not CRUD/FLS:
        RKSecurity.SecuritySavepoint sp = new RKSecurity.SecuritySavepoint();
        try {
            RKSecurity.setSecurityMode(securityMode);
            if (securityModeTransactional) {
                RKSecurity.transactionalThrow();
            }
            
            SOQLParser.SOQL soql = 
                new SOQLParser.SOQL(queryString)
                    .resolve(enforceCrudFLS);

            return assertSearchRestrictions(soql);
        } finally {
            RKSecurity.restore(sp);
        }
    }

    SOQLParser.SOQL assertSearchRestrictions(SOQLParser.SOQL soql) {
        for (RestrictedSearch rule : searchRules) {
            rule.reset();
            rule.start(soql);
            if (soql.whereCond != null) {
                // Throws RestrictedSearchException:
                soql.whereCond.traverse(rule);
            }
            rule.finish(soql);
        }
        return soql;
    }

    global virtual class RestrictedSearch extends SOQLParser.ASTVisitor {
        global String name {get; private set;}
        global Schema.SObjectType allowedType {get; private set;}

        global RestrictedSearch(String name, Schema.SObjectType allowedType) {
            this.name = name;
            this.allowedType = allowedType;
        }

        // Throws RestrictedSearchException:
        global virtual void start(SOQLParser.SOQL soql) {}

        // Throws RestrictedSearchException:
        global virtual void finish(SOQLParser.SOQL soql) {}

        global virtual void violation(String message) {
            restrictedSearchError(this, 'Restricted Search Violation [' + name + ']: ' + message);
        }

        global virtual void configError(String message) {
            restrictedSearchError(this, 'Restricted Search Configuration [' + name + ']: ' + message);
        }
    }

    global class RestrictedSearchException extends Exception {
        global RestrictedSearch rule;
    }

    global static void restrictedSearchError(RestrictedSearch rule, String message) {
        RestrictedSearchException err = new RestrictedSearchException(message);
        err.rule = rule;
        err.setMessage(message);
        throw err;
    }

    global class RestrictedToExactMatches extends RestrictedSearch {
        Map<String, ExactMatchElmt> matchElmtsByPathLC = new Map<String, ExactMatchElmt>();
        Map<String, FreestyleElmt> freeElmtsByPathLC = new Map<String, FreestyleElmt>();
        Integer minimumMatches;
        Integer matchesCounter;
        // As we encounter match and freestyle elements in a parsed WHERE clause, they are logged here:
        Map<String, SOQLParser.ASTSimpleCond> parsedElmtsByPathLC = new Map<String, SOQLParser.ASTSimpleCond>();

        global RestrictedToExactMatches(String name, Schema.SObjectType allowedType) {
            super(name, allowedType);
        }

        // This method can also be used to fire start-up validations (e.g. invalid configurations):
        global override void start(SOQLParser.SOQL soql) {
            this.matchesCounter = 0;
            this.parsedElmtsByPathLC = new Map<String, SOQLParser.ASTSimpleCond>();
            if (soql.resTable != allowedType) {
                violation('Illegal "FROM ' + soql.fromEntity.lexeme + '" clause; only "FROM ' + allowedType + '" is allowed');
            }
            if (soql.whereCond == null) {
                violation('WHERE clause is required');
            }
            if (soql.sorts != null && soql.sorts.size() > 0) {
                violation('ORDER BY clause is not allowed');
            }
            if (soql.nested != null && soql.nested.size() > 0) {
                violation('SELECT of child relationships is not allowed');
            }
            if (matchElmtsByPathLC.keySet().size() == 0) {
                configError('At least 1 match must be defined');
            }
            if (minimumMatches == null || minimumMatches < 1) {
                configError('Minimum matches must be a positive integer; got ' + minimumMatches);
            }
            for (String pathLC : freeElmtsByPathLC.keySet()) {
                if (matchElmtsByPathLC.containsKey(pathLC)) {
                    configError('Freestyle element "' + freeElmtsByPathLC.get(pathLC).path + 
                        '" conflicts with match element of same path');
                }
            }
        }

        global override void finish(SOQLParser.SOQL soql) {
            // Verify we got all match elements that were flagged as required:
            for (ExactMatchElmt matchElmt : matchElmtsByPathLC.values()) {
                if (matchElmt.isRequired) {
                    if (!parsedElmtsByPathLC.containsKey(matchElmt.path.toLowerCase())) {
                        violation('Required match condition "' + matchElmt.path + '" is not present');
                    }
                }
            }
            // Verify we got the minimum number of matches:
            Integer effectiveMin = getEffectiveMinMatches();
            if (matchesCounter < effectiveMin) {
                violation('Expected at least ' + effectiveMin + ' match conditions; got ' + matchesCounter);
            }
        }

        //global override void onStart(ASTCond root) {}
        
        global override void onCond(ASTCond cond) {
            if (cond.isOr() || cond.isNot()) {
                ASTCond parentAnd;
                for (ASTCond parent : parents()) {
                    if (parent.isAnd()) {
                        parentAnd = parent;
                        break;
                    }
                }
                if (parentAnd == null) {
                    violation((cond.isOr() ? 'OR' : 'NOT') + ' condition must be nested under a parent AND');
                }
            } else if (cond.isSimple()) {
                // These structure flags tell us where this simple condition resides within the query's 
                // AST tree structure. Exact-match elements are only allowed as the top-level conditon or
                // directly under a top-level AND condition. Freestyle elements are allowed at deeper 
                // nestings, though note other rules (above) prevent the existence of OR and NOT at the
                // top level:
                Boolean isTop = false;
                Boolean isTopAND = false;
                Boolean allParentsAND = true;
                for (ASTCond parent : parents()) {
                    //// Extra groupings don't change our structure analysis:
                    //if (parent.isGroup()) {
                    //    continue;
                    //} else {
                    
                    isTop = false;
                    // If it's under an OR or NOT then it can only qualify for "freestyle" elements. 
                    // Set both structure flags false, and we're done:
                    if (parent.isOr() || parent.isNot()) {
                        isTopAND = false;
                        allParentsAND = false;
                        break;
                    } else if (parent.isAnd()) {
                        // If it's under an AND but we were already under another AND then it's more
                        // deeply nested than top level. Set both structure flags false, and we're done:
                        if (isTopAND) {
                            isTopAND = false;
                            break;
                        // If it's under an AND and this is the first one, then it (currently) qualifies
                        // as a top-level AND. Set the isTopAND structure flag to true and continue:
                        } else {
                            isTopAND = true;
                            continue;
                        }
                    }
                    
                    //}
                }

                SOQLParser.ASTSimpleCond simpleCond = (SOQLParser.ASTSimpleCond) cond;
                String path = simpleCond.ref.getBestPath();
                ExactMatchElmt matchElmt = matchElmtsByPathLC.get(path.toLowerCase());
                FreestyleElmt freeElmt;
                if (matchElmt != null) {
                    //if (!isTop && !isTopAND) {
                    if (!(isTop || allParentsAND)) {
                        violation('Match condition "' + path + 
                            //'" cannot be nested deeper than a top-level AND condition');
                            '" cannot reside within OR or NOT conditions');
                    } else if (simpleCond.op.lexeme != '=') {
                        violation('Match condition "' + path + '" is only allowed "="; got "' + 
                            simpleCond.op.lexeme + '"');
                    } else if (simpleCond.val.isList()) {
                        violation('Match condition "' + path + 
                            '" is only allowed simple match values; got list value');
                    } else if (simpleCond.val.isUnboundNamedParam()) {
                        violation('Match condition "' + path + 
                            '" is not allowed unresolved named bind ":' + 
                            simpleCond.val.scalar.param.lexeme + '"');
                    } else {
                        matchesCounter++;
                    }
                } else {
                    freeElmt = freeElmtsByPathLC.get(path.toLowerCase());
                    if (freeElmt != null) {
                        if (freeElmt.allowNested != true && !isTop && !isTopAND) {
                            violation('Freestyle condition "' + path + 
                                '" cannot be nested deeper than a top-level AND condition');
                        } else if (freeElmt.allowAnyOp != true && simpleCond.op.lexeme != '=') {
                            violation('Freestyle condition "' + path + 
                                '" is only allowed the "=" operator; got "' + simpleCond.op.lexeme + '"');
                        }
                    // Else we have an undefined reference path, which is a violation!
                    } else {
                        violation('Condition "' + path + 
                            '" has not been defined as either an exact-match or freestyle element');
                    }
                }

                MatchElmt parsedElmt = (MatchElmt) matchElmt ?? (MatchElmt) freeElmt;
                if (parsedElmt != null) {
                    SOQLParser.ASTSimpleCond duplicateCond = 
                        parsedElmtsByPathLC.put(parsedElmt.path.toLowerCase(), simpleCond);
                    // Prevent duplicate instances of the same match element in a WHERE clause:
                    if (duplicateCond != null && parsedElmt instanceof ExactMatchElmt) {
                        violation('Match condition "' + parsedElmt.path + 
                            '" cannot be used more than once');
                    }
                }
            }
        }

        //global override void onLeaveCond(ASTCond cond) {}
        //global override void onValue(ASTValue val) {}
        //global override void onReference(ASTReference ref) {}
        //global override void onFinish(ASTCond root) {}

        global Integer getEffectiveMinMatches() {
            if (minimumMatches != null) {
                return minimumMatches;
            }
            Integer effectiveMin = 0;
            for (ExactMatchElmt matchElmt : matchElmtsByPathLC.values()) {
                if (matchElmt.isRequired) {
                    effectiveMin++;
                }
            }
            if (effectiveMin == 0) {
                effectiveMin = matchElmtsByPathLC.keySet().size();
            }
            return effectiveMin;
        }

        global RestrictedToExactMatches setMinimumMatches(Integer minMatches) {
            this.minimumMatches = minMatches;
            return this;
        }

        // Specifies an exact-match field. 
        // 1. A field condition to this path may only exist at either the conditon's top level, or 
        //    nested under AND's and Groups ONLY (no OR's or NOT's). Its appearance at other structural 
        //    position will fail this rule.
        // 2. A field condition to this path must only use a strict equals '=' operator. Use of any
        //    other operator will fail this rule.
        // 3. Any duplicate field condition on this same path will fail this rule. 
        // 4. If marked as required, a field condition to this path MUST exist in the WHERE condition,
        //    adherent to the above rules, or this rule will fail.
        // 5. A field condition to this path, and adherent to above rules, will increment the 
        //    "matchesCount" counter by 1. If, after processing the entire WHERE condition, 
        //    (matchesCounter < minimumMatches), this rule will fail.
        global RestrictedToExactMatches addExactMatchElement(String path, Boolean isRequired) {
            ExactMatchElmt matchElmt = new ExactMatchElmt();
            matchElmt.path = path;
            matchElmt.isRequired = isRequired == true;
            ExactMatchElmt oldElmt = matchElmtsByPathLC.put(path.toLowerCase(), matchElmt);
            if (oldElmt != null) {
                configError('Match element "' + path + '" was previously defined');
            }
            return this;
        }

        // Specifies an optional condition field. This path must NOT match that of any "exact match" 
        // element. A field condition to this path may exist at any level, with any operator. However, the 
        // basic ruleset for RestrictedByExactMatches still applies:
        // 1. An OR is only allowed if nested under an AND
        // 2. A NOT is only allowed if nested under an AND
        // 3. Field conditons may only use scalar literal values. List values and binding / parameter 
        //    values are not allowed, and will fail this rule. 
        // 4. Any field condition not to a path for either "exact match" or "freestyle" elements will fail 
        //    this rule.
        global RestrictedToExactMatches addFreestyleElement(String path, Boolean allowNested, Boolean allowAnyOp) {
            FreestyleElmt freeElmt = new FreestyleElmt();
            freeElmt.path = path;
            freeElmt.allowNested = allowNested == true;
            freeElmt.allowAnyOp = allowAnyOp == true;
            FreestyleElmt oldElmt = freeElmtsByPathLC.put(path.toLowerCase(), freeElmt);
            if (oldElmt != null) {
                configError('Freestyle element "' + path + '" was previously defined');
            }
            return this;
        }
    }

    public abstract class MatchElmt {
        String path;
    }

    public class ExactMatchElmt extends MatchElmt {
        Boolean isRequired = true;
    }

    public class FreestyleElmt extends MatchElmt {
        Boolean allowNested;
        Boolean allowAnyOp;
    }
}