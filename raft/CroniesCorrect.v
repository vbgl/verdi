Require Import Arith.
Require Import NPeano.
Require Import List.
Require Import Coq.Numbers.Natural.Abstract.NDiv.
Import ListNotations.
Require Import Sorting.Permutation.

Require Import Util.
Require Import Net.
Require Import RaftState.
Require Import Raft.
Require Import RaftRefinement.
Require Import CandidatesVoteForSelves.
Require Import VotesCorrect.
Require Import VerdiTactics.
Require Import CommonTheorems.

Section CroniesCorrect.
  
  Context {orig_base_params : BaseParams}.
  Context {one_node_params : OneNodeParams orig_base_params}.
  Context {raft_params : RaftParams orig_base_params}.

  Lemma candidates_vote_for_selves_l_invariant :
    forall (net : network),
      refined_raft_intermediate_reachable net ->
      candidates_vote_for_selves (deghost net).
  Proof.
    intros.
    eapply lift_prop; [exact candidates_vote_for_selves_invariant|eauto].
  Qed.

  Definition votes_received_cronies net :=
    forall h crony,
      In crony (votesReceived (snd (nwState net h))) ->
      (type (snd (nwState net h)) = Leader \/ type (snd (nwState net h)) = Candidate) ->
      In crony (cronies (fst (nwState net h))
                        (currentTerm (snd (nwState net h)))).
      
  Definition cronies_votes net :=
    forall t candidate crony,
      In crony (cronies (fst (nwState net candidate)) t) ->
      In (t, candidate) (votes (fst (nwState net crony))).

  Definition votes_nw net :=
    forall p t,
      pBody p = RequestVoteReply t true ->
      In p (nwPackets net) ->
      In (t, pDst p) (votes (fst (nwState net (pSrc p)))).

  Definition votes_received_leaders net :=
    forall h,
      type (snd (nwState net h)) = Leader ->
      wonElection (dedup name_eq_dec (votesReceived (snd (nwState net h)))) = true.

  Definition cronies_correct net :=
    votes_received_cronies net /\ cronies_votes net /\ votes_nw net /\ votes_received_leaders net.

  Lemma handleClientRequest_rvr :
    forall h net ps client id c out d l p t v,
      handleClientRequest h (snd (nwState net h)) client id c = (out, d, l) ->
      (forall p' : packet,
         In p' ps ->
         In p' (nwPackets net) \/
         In p' (send_packets h l)) ->
      pBody p = RequestVoteReply t v ->
      In p ps ->
      In p (nwPackets net).
  Proof.
    intros.
    unfold handleClientRequest in *; repeat break_match;
    repeat find_inversion; subst; simpl in *; find_apply_hyp_hyp; intuition.
  Qed.

  Lemma handleTimeout_rvr :
    forall h net ps out d l p t v,
      handleTimeout h (snd (nwState net h)) = (out, d, l) ->
      (forall p' : packet,
         In p' ps ->
         In p' (nwPackets net) \/
         In p' (send_packets h l)) ->
      pBody p = RequestVoteReply t v ->
      In p ps ->
      In p (nwPackets net).
  Proof.
    intros.
    unfold handleTimeout, tryToBecomeLeader in *; repeat break_match;
    repeat find_inversion; subst; simpl in *; find_apply_hyp_hyp;
    in_crush; congruence.
  Qed.

  Lemma handleAppendEntries_rvr :
    forall h h' s ps ps' p d r tae li pli plt es lc t v,
      handleAppendEntries h s tae li pli plt es lc = (d, r) ->
      (forall p' : packet,
         In p' ps ->
         In p' ps' \/
         p' = {| pSrc := h; pDst := h'; pBody := r |}) ->
      pBody p = RequestVoteReply t v ->
      In p ps ->
      In p ps'.
  Proof.
    intros.
    unfold handleAppendEntries, advanceCurrentTerm in *; repeat break_match;
    repeat find_inversion; subst; simpl in *; find_apply_hyp_hyp;
    in_crush; congruence.
  Qed.

  Lemma handleAppendEntriesReply_rvr :
    forall h s src ps ps' p d l tae es res t v,
      handleAppendEntriesReply h s src tae es res = (d, l) ->
      (forall p' : packet,
         In p' ps ->
         In p' ps' \/
         In p' (send_packets h l)) ->
      pBody p = RequestVoteReply t v ->
      In p ps ->
      In p ps'.
  Proof.
    intros.
    unfold handleAppendEntriesReply, advanceCurrentTerm in *; repeat break_match;
    repeat find_inversion; subst; simpl in *; find_apply_hyp_hyp;
    in_crush; congruence.
  Qed.
  
  Lemma cronies_correct_client_request :
    refined_raft_net_invariant_client_request cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_client_request. intros.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies, handleClientRequest in *. intros.
      simpl in *. repeat find_higher_order_rewrite.
      repeat break_match; find_inversion; subst; simpl in *; eauto; discriminate.
    - unfold cronies_votes in *. intros.
      simpl in *. repeat find_higher_order_rewrite.
      repeat break_match; subst; simpl in *; eauto.
    - unfold votes_nw in *. intros. simpl in *.
      assert (In p (nwPackets net)) by eauto using handleClientRequest_rvr.
      repeat find_apply_hyp_hyp.
      repeat find_higher_order_rewrite.
      repeat break_match; subst; repeat find_rewrite; simpl in *; intuition.
    - unfold votes_received_leaders in *. intros. simpl in *. repeat find_higher_order_rewrite.
      unfold handleClientRequest in *.
      repeat break_match; find_inversion; subst; simpl in *; eauto.
  Qed.

  Lemma cronies_correct_timeout :
    refined_raft_net_invariant_timeout cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_timeout. intros.
    unfold cronies_correct, update_elections_data_timeout in *; intuition.
    - unfold votes_received_cronies, handleTimeout, tryToBecomeLeader in *.
      intros. simpl in *.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto;
      repeat find_higher_order_rewrite; repeat (break_if; simpl in *); auto; congruence.
    - unfold cronies_votes, handleTimeout, tryToBecomeLeader in *. intros.
      simpl in *.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto;
      repeat find_higher_order_rewrite; repeat (break_if; simpl in *); auto;
      repeat find_inversion; subst; intuition;
      congruence.
    - unfold votes_nw in *. intros. simpl in *.
      assert (In p (nwPackets net)) by eauto using handleTimeout_rvr.
      repeat find_apply_hyp_hyp.
      repeat find_higher_order_rewrite.
      repeat break_match; subst; repeat find_rewrite; simpl in *; intuition.
    - unfold votes_received_leaders in *. intros. simpl in *. repeat find_higher_order_rewrite.
      unfold handleTimeout, tryToBecomeLeader in *. simpl in *.
      repeat (break_match; subst; simpl in *; repeat find_inversion; try discriminate);
        intuition eauto.
  Qed.

  Lemma cronies_correct_append_entries :
    refined_raft_net_invariant_append_entries cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_append_entries. intros.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies, handleAppendEntries in *.
      intros. simpl in *.
      repeat find_higher_order_rewrite.
      unfold update_elections_data_appendEntries.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto;
      repeat find_higher_order_rewrite; repeat (break_if; simpl in *); intuition; try congruence.
    - unfold cronies_votes in *. intros.
      simpl in *. repeat find_higher_order_rewrite.
      unfold update_elections_data_appendEntries in *.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto.
    - unfold votes_nw in *. intros. simpl in *.
      assert (In p0 (xs ++ ys)) by eauto using handleAppendEntries_rvr.
      assert (In p0 (nwPackets net)) by (repeat find_rewrite; in_crush).
      repeat find_apply_hyp_hyp.
      repeat find_higher_order_rewrite.
      unfold update_elections_data_appendEntries in *.
      repeat break_match; subst; repeat find_rewrite; simpl in *; intuition.
    - unfold votes_received_leaders in *. intros. simpl in *.
      repeat find_higher_order_rewrite. repeat break_if; eauto.
      subst. simpl in *. unfold handleAppendEntries in *.
      repeat break_match; find_inversion; subst; simpl in *;
      try discriminate; eauto.
  Qed.
  
  Lemma cronies_correct_append_entries_reply :
    refined_raft_net_invariant_append_entries_reply cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_append_entries_reply. intros.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies, handleAppendEntriesReply in *.
      intros. simpl in *.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto;
      repeat find_higher_order_rewrite; repeat (break_if; simpl in *); intuition; congruence.
    - unfold cronies_votes in *. intros.
      simpl in *. repeat find_higher_order_rewrite.
      repeat break_match; subst; simpl in *; eauto.
    - unfold votes_nw in *. intros. simpl in *.
      assert (In p0 (xs ++ ys)) by eauto using handleAppendEntriesReply_rvr.
      assert (In p0 (nwPackets net)) by (repeat find_rewrite; in_crush).
      repeat find_apply_hyp_hyp.
      repeat find_higher_order_rewrite.
      repeat break_match; subst; repeat find_rewrite; simpl in *; intuition.
    - unfold votes_received_leaders in *. intros. simpl in *.
      repeat find_higher_order_rewrite. repeat break_if; eauto.
      subst. simpl in *. unfold handleAppendEntriesReply in *.
      repeat break_match; find_inversion; subst; simpl in *;
      try discriminate; eauto.
  Qed.

  Lemma handleRequestVote_true_votedFor :
    forall h st t src lli llt d t',
      handleRequestVote h st t src lli llt = (d, RequestVoteReply t' true) ->
      currentTerm d = t' /\ votedFor d = Some src.
  Proof.
    intros. unfold handleRequestVote, advanceCurrentTerm in *.
    repeat (break_match; try find_inversion; try discriminate);
      simpl in *; subst; intuition.
  Qed.

  Lemma cronies_correct_request_vote :
    refined_raft_net_invariant_request_vote cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_request_vote. intros.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies, handleRequestVote,
      advanceCurrentTerm,
      update_elections_data_requestVote in *.
      intros. simpl in *.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto;
      repeat find_higher_order_rewrite; repeat (break_if; simpl in *); intuition; congruence.
    - unfold update_elections_data_requestVote, cronies_votes in *. intros.
      simpl in *. repeat break_let. subst. repeat find_higher_order_rewrite.
      repeat break_match; simpl in *; subst; intuition eauto.
    - unfold update_elections_data_requestVote, votes_nw in *. intros.
      simpl in *.
      repeat break_let. subst. repeat find_higher_order_rewrite.
      find_apply_hyp_hyp. intuition.
      + assert (In p0 (nwPackets net)) by (repeat find_rewrite; in_crush).
        repeat break_match; simpl in *;
        repeat find_reverse_rewrite; intuition eauto.
      + unfold raft_data in *. repeat find_rewrite. repeat find_inversion.
        repeat (subst; simpl in *).
        find_apply_lem_hyp handleRequestVote_true_votedFor. intuition.
        repeat find_rewrite. repeat break_match; intuition.
        simpl in *. intuition.
    - unfold votes_received_leaders in *. intros. simpl in *.
      repeat find_higher_order_rewrite. repeat break_if; eauto.
      subst. simpl in *.
      unfold handleRequestVote, advanceCurrentTerm, update_elections_data_requestVote in *.
      repeat (break_match; subst; simpl in *; try discriminate; try find_inversion); eauto.
  Qed.

  Lemma handleRequestVoteReply_candidate :
    forall h st src t v st',
      handleRequestVoteReply h st src t v = st' ->
      type st' = Candidate ->
      type st = Candidate /\ currentTerm st' = currentTerm st.
  Proof.
    intros.
    unfold handleRequestVoteReply, advanceCurrentTerm in *.
    repeat break_match; subst; simpl in *; auto; congruence.
  Qed.

  Lemma handleRequestVoteReply_votesReceived :
    forall h st src t v st' crony,
      handleRequestVoteReply h st src t v = st' ->
      In crony (votesReceived st') ->
      ((crony = src /\ v = true /\ currentTerm st' = t) \/ In crony (votesReceived st)).
  Proof.
    intros.
    unfold handleRequestVoteReply, advanceCurrentTerm in *.
    repeat break_match; simpl in *; subst; simpl in *; do_bool; intuition.
  Qed.
  
  Lemma handleRequestVoteReply_leader :
    forall h st src t v st',
      handleRequestVoteReply h st src t v = st' ->
      type st' = Leader ->
      (st' = st \/
       (type st = Candidate /\
        wonElection (dedup name_eq_dec (votesReceived st')) = true /\
        currentTerm st' = currentTerm st)).
  Proof.
    intros.
    unfold handleRequestVoteReply in *.
    repeat (break_match; subst; simpl in *; try discriminate; intuition).
  Qed.

  Lemma cronies_correct_request_vote_reply :
    refined_raft_net_invariant_request_vote_reply cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_request_vote_reply. intros.
    assert (candidates_vote_for_selves (deghost net)) by
        eauto using candidates_vote_for_selves_l_invariant.
    assert (votes_correct net) by eauto using votes_correct_invariant.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies,
      update_elections_data_requestVoteReply in *.
      intros. simpl in *.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto;
      repeat find_higher_order_rewrite; repeat (break_if; simpl in *); auto; try congruence;
      unfold raft_data in *; repeat find_rewrite; intuition; congruence.
    - unfold update_elections_data_requestVoteReply, cronies_votes in *. intros.
      simpl in *. repeat find_higher_order_rewrite.
      repeat (repeat break_match; simpl in *; subst; intuition eauto); try discriminate.
      + match goal with
          | H : type ?x = _ |- _ =>
            remember x as cst; symmetry in Heqcst
        end;
        find_copy_apply_lem_hyp handleRequestVoteReply_candidate; auto;
        repeat find_rewrite;
        unfold votes_correct, currentTerm_votedFor_votes_correct in *; intuition;
        unfold candidates_vote_for_selves in *;
        match goal with
          | H : _ |- _ => apply H
        end; intuition;
        match goal with
          | H : forall _, type _ = _ -> votedFor _ = _ |- _ = Some ?h =>
            specialize (H h)
        end;
        match goal with
        | [ H : _ |- _ ] => rewrite deghost_spec in H
        end; intuition eauto.
      + match goal with
          | H : type ?x = Leader |- _ =>
            remember x as cst; symmetry in Heqcst
        end.
        find_copy_apply_lem_hyp handleRequestVoteReply_leader; auto.
        intuition; [repeat find_rewrite; eauto|].
        find_eapply_lem_hyp handleRequestVoteReply_votesReceived; eauto.
        intuition.
        * unfold votes_nw in *.
          match goal with
            | H : _ = true |- _ => rewrite H in *; clear H
          end.
          match goal with
            | H : pBody _ = _, Hpbody : forall _ _, pBody _ = _ -> _ |- _ =>
              apply Hpbody in H
          end; [|solve [repeat find_rewrite; in_crush]].
          repeat find_rewrite; eauto.
        * repeat find_rewrite.
          unfold votes_received_cronies in *.
          eauto.
      + match goal with
          | H : type ?x = _ |- _ =>
            remember x as cst; symmetry in Heqcst
        end.
        find_copy_apply_lem_hyp handleRequestVoteReply_leader; auto.
        intuition.
        find_eapply_lem_hyp handleRequestVoteReply_votesReceived; eauto.
        intuition.
        * unfold votes_nw in *.
          match goal with
            | H : _ = true |- _ => rewrite H in *; clear H
          end.
          match goal with
            | H : pBody _ = _, Hpbody : forall _ _, pBody _ = _ -> _ |- _ =>
              apply Hpbody in H
          end; [|solve [repeat find_rewrite; in_crush]].
          repeat find_rewrite; eauto.
        * repeat find_rewrite.
          unfold votes_received_cronies in *.
          eauto.
      + match goal with
          | H : type ?x = _ |- _ =>
            remember x as cst; symmetry in Heqcst
        end.
        find_copy_apply_lem_hyp handleRequestVoteReply_candidate; auto.
        find_eapply_lem_hyp handleRequestVoteReply_votesReceived; eauto.
        intuition; repeat find_rewrite; eauto.
      + match goal with
          | H : type ?x = Leader |- _ =>
            remember x as cst; symmetry in Heqcst
        end.
        find_copy_apply_lem_hyp handleRequestVoteReply_leader; auto.
        intuition; [repeat find_rewrite; eauto|].
        find_eapply_lem_hyp handleRequestVoteReply_votesReceived; eauto.
        intuition.
        * unfold votes_nw in *.
          match goal with
            | H : _ = true |- _ => rewrite H in *; clear H
          end.
          match goal with
            | H : pBody _ = _, Hpbody : forall _ _, pBody _ = _ -> _ |- _ =>
              apply Hpbody in H
          end; [|solve [repeat find_rewrite; in_crush]].
          repeat find_rewrite; eauto.
        * repeat find_rewrite.
          unfold votes_received_cronies in *.
          eauto.
      + match goal with
          | H : type ?x = Leader |- _ =>
            remember x as cst; symmetry in Heqcst
        end.
        find_copy_apply_lem_hyp handleRequestVoteReply_leader; auto.
        intuition.
        find_eapply_lem_hyp handleRequestVoteReply_votesReceived; eauto.
        intuition.
        * unfold votes_nw in *.
          match goal with
            | H : _ = true |- _ => rewrite H in *; clear H
          end.
          match goal with
            | H : pBody _ = _, Hpbody : forall _ _, pBody _ = _ -> _ |- _ =>
              apply Hpbody in H
          end; [|solve [repeat find_rewrite; in_crush]].
          repeat find_rewrite; eauto.
        * repeat find_rewrite.
          unfold votes_received_cronies in *.
          eauto.
    - unfold votes_nw in *.
      intros.
      simpl in *. find_apply_hyp_hyp.
      match goal with
        | H : nwPackets ?net = _,
              H' : In ?p _ |- _ =>
          assert (In p (nwPackets net)) by (repeat find_rewrite; in_crush);
            clear H H'
      end.
      find_apply_hyp_hyp.
      match goal with
        | H : In ?x ?y |- In ?x ?z =>
          cut (z = y); [intros; repeat find_rewrite; auto|]
      end.
      repeat find_higher_order_rewrite.
      subst.
      unfold update_elections_data_requestVoteReply in *.
      repeat break_match; subst; simpl in *; repeat find_rewrite; auto.
    - unfold votes_received_leaders in *.
      intros. simpl in *.
      repeat find_higher_order_rewrite. break_if; [|eauto].
      simpl in *.
      find_apply_lem_hyp handleRequestVoteReply_leader; auto. intuition; subst.
      eauto.
  Qed.

  Lemma doLeader_st :
    forall st h os st' ms,
      doLeader st h = (os, st', ms) ->
      votesReceived st' = votesReceived st /\
      currentTerm st' = currentTerm st /\
      type st' = type st.
  Proof.
    intros.
    unfold doLeader, advanceCommitIndex in *.
    repeat break_match; find_inversion; intuition.
  Qed.
      

  Lemma do_leader_rvr :
    forall st h os st' ms p t ps ps',
      doLeader st h = (os, st', ms) ->
      (forall p : packet,
         In p ps' -> In p ps \/ In p (send_packets h ms)) ->
      pBody p = RequestVoteReply t true ->
      In p ps' ->
      In p ps.
  Proof.
    intros.
    unfold doLeader in *; repeat break_match; repeat find_inversion;
    simpl in *; find_apply_hyp_hyp; intuition.
    in_crush. congruence.
  Qed.
  
  Lemma cronies_correct_do_leader :
    refined_raft_net_invariant_do_leader cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_do_leader. intros.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies in *. simpl in *. intros.
      find_apply_lem_hyp doLeader_st.
      repeat find_higher_order_rewrite.
      repeat break_match; simpl in *; repeat find_rewrite; intuition eauto;
      repeat find_rewrite;
      match goal with
        | _ : nwState _ ?h = _, H : forall _ _ : name, _ |- _ =>
          specialize (H h)
      end;
      repeat find_rewrite; simpl in *; intuition eauto.
    - unfold cronies_votes in *. intros.
      simpl in *. repeat find_higher_order_rewrite.
      repeat break_if; simpl in *; subst; eauto;
      match goal with
        | [ H : forall (_ : term) (_ _ : name), _ |-
                                           In (?t, ?h) _ ] =>
          specialize (H t h)
      end;
        repeat find_rewrite; simpl in *;
        find_apply_hyp_hyp; repeat find_rewrite; intuition eauto.
    - unfold votes_nw in *. intros. simpl in *.
      find_eapply_lem_hyp do_leader_rvr; eauto.
      find_apply_hyp_hyp.
      find_higher_order_rewrite.
      break_if; auto;
      subst; simpl in *;
      repeat find_rewrite; simpl in *; auto.
    - unfold votes_received_leaders in *. intros.
      find_apply_lem_hyp doLeader_st.
      intuition. find_higher_order_rewrite. simpl in *.
      repeat break_if; simpl in *; subst; eauto.
      repeat find_rewrite.
      match goal with
        | H : ?t = (?x, ?y) |- context [ ?y ] =>
          assert (y = (snd t)) by (rewrite H; reflexivity);
          clear H;
          subst
      end. eauto.
  Qed.

  Lemma do_generic_server_pkts :
    forall h st os st' ms ps ps' p t v,
      doGenericServer h st = (os, st', ms) ->
      (forall p, In p ps' -> In p ps \/ In p (send_packets h ms)) ->
      pBody p = RequestVoteReply t v ->
      In p ps' ->
      In p ps.
  Proof.
    intros. find_apply_hyp_hyp. intuition.
    unfold doGenericServer in *.
    repeat break_match; find_inversion; simpl in *; intuition.
  Qed.

  Lemma cronies_correct_do_generic_server :
    refined_raft_net_invariant_do_generic_server cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_do_generic_server. intros.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies in *.
      intros. simpl in *.
      repeat find_higher_order_rewrite.
      unfold doGenericServer in *.
      repeat break_match; find_inversion; subst; simpl in *; eauto;
      match goal with
        | H : ?t = (?x, ?y) |- context [ ?x ] =>
          assert (x = (fst t)) by (rewrite H; reflexivity);
          assert (y = (snd t)) by (rewrite H; reflexivity);
          clear H;
          subst
      end;
      intuition eauto.
    - unfold cronies_votes in *. intros.
      simpl in *. find_higher_order_rewrite.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto;
      try match goal with
        | H : ?t = (?x, ?y) |- _ =>
          assert (x = (fst t)) by (rewrite H; reflexivity);
          assert (y = (snd t)) by (rewrite H; reflexivity);
          clear H;
          subst
          end; intuition eauto.
    - unfold votes_nw in *.
      intros. simpl in *.
      find_eapply_lem_hyp do_generic_server_pkts; eauto.
      find_apply_hyp_hyp. find_higher_order_rewrite.
      repeat break_if; subst; simpl in *; auto; find_rewrite; simpl in *; auto.
    - unfold votes_received_leaders in *. intros.
      simpl in *. find_higher_order_rewrite.
      unfold doGenericServer in *.
      repeat break_match; repeat find_inversion; subst; simpl in *; eauto;
      match goal with
        | H : nwState ?x1 ?x2 = (?x, ?y) |- _ =>
          assert (y = (snd (nwState x1 x2))) by (rewrite H; reflexivity);
            clear H; subst
      end; intuition eauto.
  Qed.
      
  Lemma cronies_correct_state_same_packet_subset :
    refined_raft_net_invariant_state_same_packet_subset cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_state_same_packet_subset. intros.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies in *. intros.
      repeat find_reverse_higher_order_rewrite. eauto.
    - unfold cronies_votes in *. intros.
      repeat find_reverse_higher_order_rewrite. eauto.
    - unfold votes_nw in *. intros.
      repeat find_reverse_higher_order_rewrite. eauto.
    - unfold votes_received_leaders in *. intros.
      repeat find_reverse_higher_order_rewrite. eauto.
  Qed.
  
  Lemma cronies_correct_reboot :
    refined_raft_net_invariant_reboot cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_reboot, reboot. intros. subst.
    unfold cronies_correct in *; intuition.
    - unfold votes_received_cronies in *. intros.
      repeat find_higher_order_rewrite. simpl in *.
      repeat break_if; simpl in *; intuition eauto.
    - unfold cronies_votes in *. intros.
      repeat find_higher_order_rewrite. simpl in *.
      repeat break_if; subst; simpl in *; intuition eauto;
      try match goal with
        | H : ?t = (?x, ?y) |- _ =>
          assert (x = (fst t)) by (rewrite H; reflexivity);
          assert (y = (snd t)) by (rewrite H; reflexivity);
          clear H;
          subst
          end; intuition eauto.
    - unfold votes_nw in *. intros.
      repeat find_higher_order_rewrite. simpl in *.
      repeat break_if; subst; simpl in *; intuition eauto;
      try match goal with
        | H : ?t = (?x, ?y) |- _ =>
          assert (x = (fst t)) by (rewrite H; reflexivity);
          assert (y = (snd t)) by (rewrite H; reflexivity);
          clear H;
          subst
          end; intuition eauto.
    - unfold votes_received_leaders in *. intros.
      repeat find_higher_order_rewrite. simpl in *.
      repeat break_if; subst; simpl in *; intuition eauto;
      try match goal with
        | H : ?t = (?x, ?y) |- _ =>
          assert (x = (fst t)) by (rewrite H; reflexivity);
          assert (y = (snd t)) by (rewrite H; reflexivity);
          clear H;
          subst
          end; intuition eauto; discriminate.
  Qed.

  Lemma cronies_correct_init :
    refined_raft_net_invariant_init cronies_correct.
  Proof.
    unfold refined_raft_net_invariant_init, cronies_correct, step_m_init.
    unfold votes_received_cronies, cronies_votes, votes_nw, votes_received_leaders.
    simpl. intuition. discriminate.
  Qed.

  Theorem cronies_correct_invariant :
    forall (net : network),
      refined_raft_intermediate_reachable net ->
      cronies_correct net.
  Proof.
    intros.
    eapply refined_raft_net_invariant; eauto.
    - apply cronies_correct_init.
    - apply cronies_correct_client_request.
    - apply cronies_correct_timeout.
    - apply cronies_correct_append_entries.
    - apply cronies_correct_append_entries_reply.
    - apply cronies_correct_request_vote.
    - apply cronies_correct_request_vote_reply.
    - apply cronies_correct_do_leader.
    - apply cronies_correct_do_generic_server.
    - apply cronies_correct_state_same_packet_subset.
    - apply cronies_correct_reboot.
  Qed.

  Lemma won_election_cronies :
    forall net h,
      cronies_correct net ->
      type (snd (nwState net h)) = Leader ->
      wonElection (dedup name_eq_dec (cronies (fst (nwState net h))
                                              (currentTerm (snd (nwState net h))))) = true.
  Proof.
    intros.
    unfold cronies_correct in *; intuition.
    eapply wonElection_no_dup_in;
      eauto using NoDup_dedup, in_dedup_was_in, dedup_In.
  Qed.

End CroniesCorrect.
