1. As a user I can add named tasks
2. As a user I can set tasks as dependencies of other task, so that I can specify which tasks need to be completed first
3. As a user I can add subtasks to a task, so that I can break a large task into smaller parts for easier management
4. As a user I can add a note to each task to provide additional details about the task
   - each note is rendered as obsidian-flavoured markdown
   - In any view of the tasks, only the first line of the note is visible by default
5. As a user I can add my teammates
6. As a user I can can assign tasks to teammates so that I can keep track of the team's responsibilities
7. As a user I can add named milestones so that I can break down the project into cohesive parts
8. As a user I can assign tasks to milestones so that I can classify the tasks into cohesive parts of the project
   - Recursively assigns the milestone to each subtask and requisite task without a milestone
9. As a user I can assign a deadline to a milestone so that I can maintain a timeline of when each part of the project is due
10. As a user I can assign a deadline to a task so that I can maintain a timeline of when each task is due
    - I am warned before assigning a deadline to a task later than that of a task that depends on it
    - I am warned before assigning a deadline to a subtask later than that of the task that contains
    - I am warned before assigning a deadline to a subtask later than that of the milestone it is assigned to
11. As a user I can set the completion status of a task so that I can keep track of which tasks are pending
    - I am warned before marking a task complete if any of its subtasks or requisite tasks are incomplete
      - proceeding to do so will also mark all subtasks and requisite tasks as complete
12. As a user I can set the priority of a task so that I can keep track of which are the most urgent tasks
    - overdue tasks are automatically given the highest priority
13. As a user I can delete tasks
    - When I delete a task, its sub-tasks are also deleted
    - I am warned before deleting a task which is a dependency of another task
14. As a user I can save and load the schedule so that I can keep track of the added tasks in the future
    - Whenever I add, delete or edit a task, the changes are saved to disk
    - Whenever I launch the app, the schedule is loaded automatically
15. As a user I can import and export the schedule so that I can share the schedule with teammates and other devices
    - My teammates can access the schedule by importing the schedule to the app on their devices
16. As a user I can see a graph view of the entire schedule so that I can visualise the current state of the project at a glance
    - All edges in the graph view are arrow that must point from left to right
    - ==The milestones are explicitly shown as items in the graph view==
    - The other deadlines are explicitly shown as items in the graph view
17. As a user I can highlight parts of the graph view by different criteria so that I can focus on specific parts of the schedule
    - I can highlight the tasks which are due at or before a specified datetime
    - I can highlight the tasks belonging to a particular milestone
    - I can highlight the tasks which are incomplete
    - I can highlight the tasks with at least some level of priority
    - I can highlight the tasks assigned to a person or set of persons
    - I can highlight the tasks whose dependencies have been completed
    - I can combine the above criteria to highlight tasks that match all the criteria
    - I can combine the above criteria to highlight tasks that match each criteria separately, such that the highlights do not interfere
18. As a user I can select a task to see a graph view of its subtasks, parent task and all tasks that it depends on and all tasks that depends on it, so that I can examine which tasks are related to a task
19. As a user I can search for items by name
    - Whenever I have to select tasks, people or milestones from a menu, I can also search by name in the same menu
    - The menu updates to show the closest matches
20. As a user I can use default values from other tasks to add a new task, so that I can quickly add similar tasks
    * When I add a new task, the values from the most recently added task are used by default
    * I can select a task to duplicate its values when adding a new task
