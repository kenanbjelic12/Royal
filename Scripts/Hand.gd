class_name Hand
extends RefCounted
## A battle deck cycling through a hand: HAND_SIZE cards are playable, the rest
## wait in a queue. A played card goes to the back of the queue and the next
## queued card takes its slot (Clash-style card cycle).

const HAND_SIZE := 5

var slots: Array[MonsterData] = []
var queue: Array[MonsterData] = []

func _init(deck: Array, shuffle := true) -> void:
	var cards: Array[MonsterData] = []
	for c in deck:
		cards.append(c)
	if shuffle:
		cards.shuffle()
	for i in cards.size():
		if i < HAND_SIZE:
			slots.append(cards[i])
		else:
			queue.append(cards[i])

func next_card() -> MonsterData:
	return queue[0] if not queue.is_empty() else null

## Plays slot i: returns the played card and refills the slot.
func play(i: int) -> MonsterData:
	var card := slots[i]
	if not queue.is_empty():
		slots[i] = queue.pop_front()
		queue.append(card)
	return card

func index_of(card: MonsterData) -> int:
	return slots.find(card)
